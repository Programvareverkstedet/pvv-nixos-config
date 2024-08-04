{ lib, config, ... }:

{

  services.spotifyd.enable = true;
  # https://docs.spotifyd.rs/config/File.html
  services.spotifyd.settings = {
    device_name = "${config.networking.hostName}-spotifyd";
    device_type = "t_v"; # in ["unknown" "computer" "tablet" "smartphone" "speaker" "t_v"],
    bitrate = 160; # in [96 160 320]
    volume_normalisation = true;
    zeroconf_port = 44677; # instead of user/password

    # this is the place you add blinkenlights
    #on_song_change_hook = "rm -rf / --no-preserve-root";
  };

  systemd.services.spotifyd.serviceConfig = {
    SupplementaryGroups = [
      "audio"
      "pipewire"
    ];
  };

  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.addresses = true;
  services.avahi.publish.domain = true;
  services.avahi.extraServiceFiles.spotifyd = ''
    <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
      <name replace-wildcards="yes">%h</name>
      <service>
        <type>_spotify-connect._tcp</type>
        <port>${builtins.toString config.services.spotifyd.settings.zeroconf_port}</port>
      </service>
    </service-group>
  '';

  networking.firewall.allowedTCPPorts = [ config.services.spotifyd.settings.zeroconf_port ];
  networking.firewall.allowedUDPPorts = [ 5353 ]; # mDNS

}
