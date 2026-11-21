{ lib, values, ... }:
{
  systemd.network.enable = true;
  networking.domain = "pvv.ntnu.no";
  networking.useDHCP = false;

  # The rest of the networking configuration is usually sourced from /values.nix

  services.resolved = {
    enable = lib.mkDefault true;
    settings.Resolve = {
      DNSSEC = false; # Supposedly this keeps breaking and the default is to allow downgrades
      LLMNR = false;
      MulticastDNS = false;

      # Use Quad9 as fallback if NTNU's DNS go poof.
      FallbackDNS = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];

      StaleRetentionSec = "1h";
    };
  };
}
