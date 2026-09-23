{ config, fp, lib, ... }:
{
  sops.defaultSopsFile = let
    secretsFilePath = fp /secrets/${config.networking.hostName}/${config.networking.hostName}.yaml;
  in lib.mkIf (builtins.pathExists secretsFilePath) secretsFilePath;

  sops.age = lib.mkIf (config.sops.secrets != { }) {
    sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
    keyFile = "/var/lib/sops-nix/key.txt";
    generateKey = true;
  };

  security.audit = lib.mkIf (config.security.audit.enable && config.sops.secrets != { }) {
    rules = [
      # Read of files containing secrets.
      "-w /var/lib/sops-nix/key.txt -p r -k secrets"
      "-w /run/secrets -p r -k secrets"
    ];
  };
}
