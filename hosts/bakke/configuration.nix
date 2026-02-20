{
  config,
  pkgs,
  values,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../base
    ./filesystems.nix
  ];

  networking.hostId = "99609ffc";
  systemd.network.networks."30-enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.bakke; [
      (ipv4 + "/25")
      (ipv6 + "/64")
    ];
  };

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "24.05";
}
