{config, lib, pkgs, inputs, values, ...}:

{
  # lfmao
  containers.jokum = {
    autoStart = true;
    # wtf
    #path = inputs.self.nixosConfigurations.jokum.config.system.build.toplevel;
    interfaces = [ "enp6s0f1" ];
    bindMounts = {
      "/data" = { hostPath = "/data/jokum"; isReadOnly = false; };
    };
    config = {config, pkgs, ...}: let
      inherit values inputs;
    in {
      imports = [
        inputs.sops-nix.nixosModules.sops
        inputs.matrix-next.nixosModules.synapse

        ../../jokum/services/matrix
        ../../jokum/services/nginx
      ];

      _module.args = {
        inherit values inputs;
      };

      sops.defaultSopsFile = ../../../secrets/jokum/jokum.yaml;
      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";
      sops.age.generateKey = true;

      services.openssh = {
        enable = true;
        permitRootLogin = "yes";
      };

      systemd.network.enable = true;

      networking.useHostResolvConf = false;

      systemd.network.networks."30-enp6s0f1" = values.defaultNetworkConfig // {
        matchConfig.Name = "enp6s0f1";
        address = with values.hosts.jokum; [ (ipv4 + "/25") (ipv6 + "/64") ]
          ++ (with values.services.turn; [ (ipv4 + "/25") (ipv6 + "/64") ]);
      };

      system.stateVersion = "21.05";
    };
  };
}
