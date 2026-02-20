{
  config,
  fp,
  pkgs,
  values,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (fp /base)

    ./services/grzegorz.nix
  ];

  systemd.network.networks."30-eno1" = values.defaultNetworkConfig // {
    matchConfig.Name = "eno1";
    address = with values.hosts.brzeczyszczykiewicz; [
      (ipv4 + "/25")
      (ipv6 + "/64")
    ];
  };

  fonts.fontconfig.enable = true;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "25.11";
}
