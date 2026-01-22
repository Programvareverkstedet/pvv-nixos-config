{
  fp,
  lib,
  values,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    (fp /base)
  ];

  boot.loader.systemd-boot.enable = false;

  systemd.network.enable = lib.mkForce false;
  networking =
    let
      hostConf = values.hosts.gluttony;
    in
    {
      tempAddresses = "disabled";
      useDHCP = false;

      search = values.defaultNetworkConfig.domains;
      nameservers = values.defaultNetworkConfig.dns;
      defaultGateway.address = hostConf.ipv4_internal_gw;

      interfaces."ens3" = {
        ipv4.addresses = [
          {
            address = hostConf.ipv4;
            prefixLength = 32;
          }
          {
            address = hostConf.ipv4_internal;
            prefixLength = 24;
          }
        ];
        ipv6.addresses = [
          {
            address = hostConf.ipv6;
            prefixLength = 64;
          }
        ];
      };
    };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
