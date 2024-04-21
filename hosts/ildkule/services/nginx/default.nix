{ config, values, ... }:
{
  services.nginx = {
    enable = true;
    enableReload = true;
  };
}
