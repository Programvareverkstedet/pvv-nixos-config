{ lib, values, ... }:
{
  systemd.network.enable = true;
  networking.domain = "pvv.ntnu.no";
  networking.useDHCP = false;

  # The rest of the networking configuration is usually sourced from /values.nix

  services.resolved = {
    enable = lib.mkDefault true;
    dnssec = "false"; # Supposdly this keeps breaking and the default is to allow downgrades anyways...
  };
}
