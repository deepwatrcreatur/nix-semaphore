{ config, lib, pkgs, ... }:

let
  cfg = config.services.semaphore;

  # Build semaphore package inline so it doesn't require overlay
  defaultPackage = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "semaphore";
    version = "2.17.26";

    src = pkgs.fetchurl {
      url = "https://github.com/semaphoreui/semaphore/releases/download/v${version}/semaphore_${version}_linux_amd64.tar.gz";
      sha256 = "sha256-kdq7yaFR8axKrWxcfCKkj02vLkN1C6tOioq6vFcrlIc=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    sourceRoot = ".";
    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin
      install -m755 semaphore $out/bin/semaphore
      wrapProgram $out/bin/semaphore \
        --prefix PATH : ${lib.makeBinPath [ pkgs.ansible pkgs.git pkgs.openssh ]}
    '';
  };

  # Base config (cookie keys are added at runtime)
  baseConfig = {
    bolt = {
      host = "${cfg.dataDir}/database.boltdb";
    };
    dialect = "bolt";
    tmp_path = "${cfg.dataDir}/tmp";
    playbook_path = cfg.playbookPath;
    web_host = cfg.host;
    port = toString cfg.port;
    interface = cfg.interface;
    email_alert = cfg.emailAlert;
    telegram_alert = cfg.telegramAlert;
    slack_alert = cfg.slackAlert;
    concurrency_mode = cfg.concurrencyMode;
    max_parallel_tasks = cfg.maxParallelTasks;
    # Allow cookies over HTTP (not just HTTPS)
    cookie_secure = false;
  };

  baseConfigFile = pkgs.writeText "semaphore-config-base.json" (builtins.toJSON baseConfig);

in {
  options.services.semaphore = {
    enable = lib.mkEnableOption "Semaphore Ansible UI";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "The Semaphore package to use.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "semaphore";
      description = "User account under which Semaphore runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "semaphore";
      description = "Group under which Semaphore runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/semaphore";
      description = "Directory where Semaphore stores its data.";
    };

    playbookPath = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.dataDir}/playbooks";
      description = "Directory where Semaphore stores cloned repositories.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Web host URL (for links in notifications).";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Interface to bind to (empty = all interfaces).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port to listen on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for Semaphore.";
    };

    emailAlert = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable email alerts.";
    };

    telegramAlert = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Telegram alerts.";
    };

    slackAlert = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Slack alerts.";
    };

    concurrencyMode = lib.mkOption {
      type = lib.types.enum [ "" "project" "node" ];
      default = "";
      description = "Concurrency mode for task execution.";
    };

    maxParallelTasks = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Maximum parallel tasks (0 = unlimited).";
    };

    initialAdmin = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial admin username.";
      };

      email = lib.mkOption {
        type = lib.types.str;
        default = "admin@localhost";
        description = "Initial admin email.";
      };

      password = lib.mkOption {
        type = lib.types.str;
        default = "changeme";
        description = "Initial admin password. Change after first login!";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "Admin";
        description = "Initial admin display name.";
      };
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra groups for the Semaphore user (e.g., for SSH key access).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add semaphore package to system
    environment.systemPackages = [ cfg.package ];

    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      extraGroups = cfg.extraGroups;
      description = "Semaphore service user";
    };

    users.groups.${cfg.group} = { };

    # Create data directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/tmp 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.playbookPath} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Systemd service
    systemd.services.semaphore = {
      description = "Semaphore Ansible UI";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = pkgs.writeShellScript "semaphore-setup" ''
          # Generate cookie keys if they don't exist
          SECRETS_FILE="${cfg.dataDir}/.secrets"
          if [ ! -f "$SECRETS_FILE" ]; then
            echo "Generating cookie encryption keys..."
            COOKIE_HASH=$(${pkgs.openssl}/bin/openssl rand -hex 32)
            COOKIE_ENCRYPTION=$(${pkgs.openssl}/bin/openssl rand -hex 16)
            echo "COOKIE_HASH=$COOKIE_HASH" > "$SECRETS_FILE"
            echo "COOKIE_ENCRYPTION=$COOKIE_ENCRYPTION" >> "$SECRETS_FILE"
            chmod 600 "$SECRETS_FILE"
          fi

          # Load secrets
          source "$SECRETS_FILE"

          # Generate config with cookie keys
          ${pkgs.jq}/bin/jq \
            --arg cookie_hash "$COOKIE_HASH" \
            --arg cookie_encryption "$COOKIE_ENCRYPTION" \
            '. + {cookie_hash: $cookie_hash, cookie_encryption: $cookie_encryption}' \
            ${baseConfigFile} > ${cfg.dataDir}/config.json
          chmod 600 ${cfg.dataDir}/config.json

          # Initialize database if needed
          if [ ! -f ${cfg.dataDir}/database.boltdb ]; then
            echo "Initializing Semaphore database..."
            ${cfg.package}/bin/semaphore user add \
              --config ${cfg.dataDir}/config.json \
              --login "${cfg.initialAdmin.username}" \
              --email "${cfg.initialAdmin.email}" \
              --name "${cfg.initialAdmin.name}" \
              --password "${cfg.initialAdmin.password}" \
              --admin || true
          fi
        '';
        ExecStart = "${cfg.package}/bin/semaphore server --config ${cfg.dataDir}/config.json";
        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        ReadWritePaths = [ cfg.dataDir cfg.playbookPath ];
      };
    };

    # Firewall
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
