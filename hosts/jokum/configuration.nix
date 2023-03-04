{ config, pkgs, values, ... }:
{
  imports = [
      ../../base.nix
      ../../misc/metrics-exporters.nix
      ../../misc/rust-motd.nix

      ./services/matrix
      ./services/nginx
    ];

  sops.defaultSopsFile = ../../secrets/jokum/jokum.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;
  
  boot.kernel.enable = false;
  boot.isContainer = true;
  networking.useHostResolvConf = false;
  boot.loader.initScript.enable = true;

  networking.hostName = "jokum"; # Define your hostname.

  systemd.network.networks."30-ens10f1" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens10f1";
    address = with values.hosts.jokum; [ (ipv4 + "/25") (ipv6 + "/64") ]
      ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  ];

  # List services that you want to enable:

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}
