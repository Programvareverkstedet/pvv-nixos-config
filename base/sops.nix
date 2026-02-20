{
  config,
  fp,
  lib,
  ...
}:
{
  sops.defaultSopsFile =
    let
      secretsFilePath = fp /secrets/${config.networking.hostName}/${config.networking.hostName}.yaml;
    in
    lib.mkIf (builtins.pathExists secretsFilePath) secretsFilePath;

  sops.age = lib.mkIf (config.sops.defaultSopsFile != null) {
    sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
    keyFile = "/var/lib/sops-nix/key.txt";
    generateKey = true;
  };
}
