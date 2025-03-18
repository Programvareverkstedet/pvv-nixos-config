{ lib, ... }:

# This enables
#     lib.mkIf (!config.virtualisation.isVmVariant) { ... }

{
  options.virtualisation.isVmVariant = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  config.virtualisation.vmVariant = {
    virtualisation.isVmVariant = true;
  };
}
