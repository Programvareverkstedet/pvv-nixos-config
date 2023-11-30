{ config, pkgs, values, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../base.nix
      ../../misc/metrics-exporters.nix

      ./services/openvpn-client.nix
    ];

  # buskerud does not support efi?
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "buskerud";
  networking.search = [ "pvv.ntnu.no" "pvv.org" ];
  networking.nameservers = [ "129.241.0.200" "129.241.0.201" ];
  networking.tempAddresses = "disabled";

  systemd.network.networks."enp3s0f0" = values.defaultNetworkConfig // {
    matchConfig.Name = "enp3s0f0";
    address = with values.hosts.buskerud; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # Buskerud should use the default gateway received from DHCP
  networking.interfaces.enp14s0f1.useDHCP = true;

  # networking.interfaces.tun = {
  #   virtual = true;
  #   ipv4.adresses = [ {address="129.241.210.252"; prefixLength=25; } ];
  # };

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
  system.stateVersion = "23.05"; # Did you read the comment?

}
