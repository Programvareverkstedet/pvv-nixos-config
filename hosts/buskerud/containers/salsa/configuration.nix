{ config, pkgs, lib, inputs, values, ... }:
{
  containers.salsa = {
    autoStart = true;
    interfaces = [ "enp6s0f1" ];
    bindMounts = {
      "/data" = { hostPath = "/data/salsa"; isReadOnly = false; };
    };
    nixpkgs = inputs.nixpkgs-unstable;

    config = { config, pkgs, ... }: let
      inherit values inputs;
    in {
      imports = [
        inputs.sops-nix.nixosModules.sops
        ../../../../base.nix

        ./services/heimdal
        ./services/openldap.nix
        ./services/saslauthd.nix

	# https://github.com/NixOS/nixpkgs/pull/287611
	./modules/krb5
	./modules/kerberos
      ];

      disabledModules = [
	"security/krb5"
	"services/system/kerberos/default.nix"
      ];

      _module.args = {
        inherit values inputs;
      };

      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      sops.age.generateKey = true;

      # systemd.network.networks."30-enp6s0f1" = values.defaultNetworkConfig // {
      #   matchConfig.Name = "enp6s0f1";
      #   address = with values.hosts.jokum; [ (ipv4 + "/25") (ipv6 + "/64") ]
      #     ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
      # };

      networking.useHostResolvConf = lib.mkForce false;

      system.stateVersion = "23.11";
    };
  };
}
