{ fp, values, lib, lupineName, ... }:
{
  imports = [
    ./hardware-configuration/${lupineName}.nix

    (fp /base)
    ./services/gitea-runner.nix
  ];

  sops.defaultSopsFile = fp /secrets/lupine/lupine.yaml;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "i686-linux"
  ];

  systemd.network = if (lupineName != "lupine-5")
    then {
      networks."30-enp0s31f6" =  (values.defaultNetworkConfig // {
        matchConfig.Name = "enp0s31f6";
        address = with values.hosts.${lupineName}; [ (ipv4 + "/25") (ipv6 + "/64") ];
        networkConfig.LLDP = false;
      });

      wait-online = {
        anyInterface = true;
      };
    }
    else {
      netdevs."10-br0".netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };

      netdevs."20-tap0".netdevConfig = {
        Name = "tap0";
        Kind = "tap";
      };

      networks."10-enp0s31f6" = {
        matchConfig.Name = "enp0s31f6";
        bridge = [ "br0" ];
      };

      networks."20-br0" = {
        matchConfig.Name = "br0";

        address = with values.hosts.${lupineName}; [ (ipv4 + "/25") (ipv6 + "/64") ];
        networkConfig.LLDP = false;

        dns = ["129.241.0.200" "129.241.0.201" "2001:700:300:1900::200" "2001:700:300:1900::201"];
        domains = ["pvv.ntnu.no" "pvv.org"];
        gateway = [values.hosts.gateway values.hosts.gateway6];

        networkConfig.IPv6AcceptRA = "no";
        DHCP = "no";
      };

      networks."30-tap0" = {
        matchConfig.Name = "tap0";
        bridge = [ "br0" ];
      };

      wait-online = {
        anyInterface = true;
      };
    };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.05";
}
