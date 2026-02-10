{
  fp,
  lib,
  values,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./disk-config.nix
    (fp /base)
  ];

  systemd.network.networks."enp2s0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp2s0";
    address = with values.hosts.skrot; [
      (ipv4 + "/25")
      (ipv6 + "/64")
    ];
  };

  system.stateVersion = "26.05"; # Did you read the comment?
}
