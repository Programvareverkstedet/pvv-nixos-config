{ config, lib, ... }:
let
  cfg = config.boot.kernel.hugepages;
in
{
  options.boot.kernel.hugepages = {
    size = lib.mkOption {
      type = lib.types.enum [ 2 1024 ];
      default = 2;
      description = ''
        Hugepage size in MB.

        You can use this value to calculate the amount of memory you will have available as hugepages.
      '';
    };

    reservations = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.unsigned;
      default = { };
      description = ''
        Number of hugepages each service wants reserved in vm.nr_hugepages,
        keyed by service name.
      '';
    };
  };

  config = {
    boot.kernelParams = let
      num = {
        "2" = "2M";
        "1024" = "1G";
      }.${toString cfg.size};
    in [ "hugepagesz=${num}" ];

    boot.kernel.sysctl."vm.nr_hugepages" =
      lib.foldl' (a: b: a + b) 0 (lib.attrValues cfg.reservations);
  };
}
