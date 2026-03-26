# nix-semaphore

NixOS module and package for [Semaphore](https://semaphoreui.com) - a modern UI for Ansible, Terraform, OpenTofu, and other DevOps tools.

## Features

- Declarative NixOS service configuration
- SQLite database (no external database required)
- Automatic cookie key generation
- Initial admin user creation
- Systemd hardening
- Optional firewall configuration

## Installation

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-semaphore.url = "github:deepwatrcreatur/nix-semaphore";
  };
}
```

Import the module in your NixOS configuration:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.nix-semaphore.nixosModules.default
  ];
}
```

## Usage

### Basic Configuration

```nix
{
  services.semaphore = {
    enable = true;
    port = 3000;
    openFirewall = true;

    initialAdmin = {
      username = "admin";
      email = "admin@example.com";
      password = "changeme";  # Change after first login!
      name = "Administrator";
    };
  };
}
```

### Full Configuration Options

```nix
{
  services.semaphore = {
    enable = true;

    # Package (uses built-in by default)
    # package = pkgs.semaphore;

    # Service user/group
    user = "semaphore";
    group = "semaphore";
    extraGroups = [ "keys" ];  # For SSH key access

    # Paths
    dataDir = "/var/lib/semaphore";
    playbookPath = "/var/lib/semaphore/playbooks";

    # Network
    host = "https://semaphore.example.com";  # For notification links
    interface = "";  # Empty = all interfaces
    port = 3000;
    openFirewall = true;

    # Alerts
    emailAlert = false;
    telegramAlert = false;
    slackAlert = false;

    # Task execution
    concurrencyMode = "";  # "", "project", or "node"
    maxParallelTasks = 0;  # 0 = unlimited

    # Initial admin (only used on first run)
    initialAdmin = {
      username = "admin";
      email = "admin@example.com";
      password = "changeme";
      name = "Admin";
    };
  };
}
```

## Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Semaphore service |
| `package` | package | built-in | Semaphore package to use |
| `user` | string | `"semaphore"` | Service user |
| `group` | string | `"semaphore"` | Service group |
| `extraGroups` | list | `[]` | Extra groups for service user |
| `dataDir` | path | `/var/lib/semaphore` | Data directory |
| `playbookPath` | path | `${dataDir}/playbooks` | Repository clone directory |
| `host` | string | `""` | Web host URL for notifications |
| `interface` | string | `""` | Bind interface (empty = all) |
| `port` | int | `3000` | Listen port |
| `openFirewall` | bool | `false` | Open firewall port |
| `emailAlert` | bool | `false` | Enable email alerts |
| `telegramAlert` | bool | `false` | Enable Telegram alerts |
| `slackAlert` | bool | `false` | Enable Slack alerts |
| `concurrencyMode` | enum | `""` | Task concurrency mode |
| `maxParallelTasks` | int | `0` | Max parallel tasks (0 = unlimited) |
| `initialAdmin.*` | - | - | Initial admin user settings |

## Using with Reverse Proxy

Example Caddy configuration:

```nix
services.caddy.virtualHosts."semaphore.example.com".extraConfig = ''
  reverse_proxy localhost:3000
'';
```

## Data Storage

Semaphore stores its data in `dataDir` (default: `/var/lib/semaphore`):

- `database.sqlite` - SQLite database
- `config.json` - Runtime configuration
- `.secrets` - Cookie encryption keys
- `playbooks/` - Cloned repositories
- `tmp/` - Temporary files

## Security Notes

- Change the initial admin password after first login
- Cookie keys are auto-generated and stored in `.secrets`
- Service runs with systemd hardening (NoNewPrivileges, ProtectSystem, etc.)
- Consider using a reverse proxy with HTTPS in production

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`

## License

MIT
