{ lib, ... }:

# This enables
#     lib.mkIf (!config.virtualisation.isVmVariant) { ... }

{
  options.virtualisation.isVmVariant = lib.mkOption {
    description = "`true` if system is build with 'nixos-rebuild build-vm'";
    type = lib.types.bool;
    default = false;
  };
  config.virtualisation.vmVariant = {
    virtualisation.isVmVariant = true;
  };
}
