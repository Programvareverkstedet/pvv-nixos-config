{ config, ... }:
{
  services.scrutiny.collector = {
    enable = !config.services.qemuGuest.enable;
    settings = {
      version = 1;
      host.id = config.networking.hostName;
      api.endpoint = "https://scrutiny.pvv.ntnu.no/";
    };
  };
}
