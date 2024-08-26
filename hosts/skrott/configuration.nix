{ lib, values, ... }: {
  system.stateVersion = "22.05";

  systemd.network.networks."30-all" = values.defaultNetworkConfig // {
    matchConfig.Name = "eth0";
    address = with values.hosts.skrott; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  networking.hostName = lib.mkForce "skrot";
}
