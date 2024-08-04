{ config, ... }:

{

  services.spotifyd.enable = true;
  # https://docs.spotifyd.rs/config/File.html
  services.spotifyd.settings = {
    device_name = "${config.networking.hostName}-spotifyd";
    device_type = "speaker"; # in ["unknown" "computer" "tablet" "smartphone" "speaker" "t_v"],
    bitrate = 160; # in [96 160 320]
    volume_normalisation = true;
    zeroconf_port = 1234; # instead of user/password

    # this is the place you add blinkenlights
    #on_song_change_hook = "rm -rf / --no-preserve-root";
  };

  networking.firewall.allowedTCPPorts = [ config.services.spotifyd.settings.zeroconf_port ];
  networking.firewall.allowedUDPPorts = [
    5353 # mDNS
  ];

}
