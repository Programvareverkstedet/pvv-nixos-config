{ config, inputs, ... }:
{
  sops.secrets = {
    "dibbler/config" = {
      owner = "dibbler";
      group = "dibbler";
    };
  };
  services.dibbler.package = inputs.dibbler.packages.dibbler;
  services.dibbler.config = config.sops.secrets."dibbler/config".path;
}