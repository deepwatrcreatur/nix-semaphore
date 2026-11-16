{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, ansible
, git
, openssh
}:

stdenvNoCC.mkDerivation rec {
  pname = "semaphore";
  version = "2.20.23";

  src = fetchurl {
    url = "https://github.com/semaphoreui/semaphore/releases/download/v${version}/semaphore_${version}_linux_amd64.tar.gz";
    sha256 = "sha256-icvumDJVU04WfxQLjFi05Zc7dhr97uo/2BpYCf9qgxg=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 semaphore $out/bin/semaphore

    wrapProgram $out/bin/semaphore \
      --prefix PATH : ${lib.makeBinPath [ ansible git openssh ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Modern UI for Ansible, Terraform, OpenTofu, and other DevOps tools";
    homepage = "https://semaphoreui.com";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "semaphore";
  };
}
