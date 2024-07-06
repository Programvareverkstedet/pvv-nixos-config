
{ config, pkgs, values, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../base.nix
    ../../misc/metrics-exporters.nix
  ];

  # buskerud does not support efi?
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "dagali";
  networking.search = [ "pvv.ntnu.no" "pvv.org" ];
  networking.nameservers = [ "129.241.0.200" "129.241.0.201" ];
  networking.tempAddresses = "disabled";
  networking.networkmanager.enable = true;

  systemd.network.networks."ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.dagali; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    # TODO: consider adding to base.nix
    nix-output-monitor
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
