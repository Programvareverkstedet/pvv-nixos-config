{ lib, pkgs, ... }:
{
  systemd.services.duperemove-gitea-web = {
    description = "Deduplicate /var/lib/gitea-web contents";
    startAt = "hourly";

    confinement.enable = true;

    serviceConfig = {
      Type = "oneshot";
      CacheDirectory = "duperemove";
      DynamicUser = true;

      ExecStart =
        let
          args = lib.cli.toCommandLineShellGNU { } {
            d = true;
            r = true;
            hashfile = "%C/duperemove/gitea-web.hash";
            "io-threads" = 2;
            "cpu-threads" = 2;
            b = "4k";
            "dedupe-options" = "partial";
            "batchsize" = 128;
          };
        in
        "${lib.getExe pkgs.duperemove} ${args} /var/lib/gitea-web";

      BindPaths = [ "/var/lib/gitea-web" ];

      Nice = 19;
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";

      PrivateNetwork = true;
      CapabilityBoundingSet = [ "CAP_DAC_OVERRIDE" ];
      AmbientCapabilities = [ "CAP_DAC_OVERRIDE" ];
      PrivateUsers = lib.mkForce false;
    };
  };
}
