{ config, fp, pkgs, values, lib, ... }:
{
  imports = [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (fp /base)
    ];

  nix.settings.trusted-users = [ "@nix-builder-users" ];
  nix.daemonCPUSchedPolicy = "batch";

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
  ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.device = "/dev/sda";

  systemd.network.networks."30-ens18" = values.defaultNetworkConfig // {
    matchConfig.Name = "ens18";
    address = with values.hosts.wenche; [ (ipv4 + "/25") (ipv6 + "/64") ];
  };

  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  services.qemuGuest.enable = true;

  # Don't change (even during upgrades) unless you know what you are doing.
  # See https://search.nixos.org/options?show=system.stateVersion
  system.stateVersion = "24.11";
}
