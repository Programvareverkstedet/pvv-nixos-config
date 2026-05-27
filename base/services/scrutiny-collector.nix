{ config, ... }:
{
  services.scrutiny.collector = {
    enable = !config.virtualisation.isVmVariant;
    settings = {
      version = 1;
      host.id = config.networking.hostName;
      api.endpoint = "https://scrutiny.pvv.ntnu.no/";
    };
  };
}
