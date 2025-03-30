{ config, lib, pkgs, ... }:
let
  cfg = config.services.gickup;
in
{
  config = lib.mkIf cfg.enable {
    # TODO: add a service that will look at the backed up files and hardlink
    #       the ones that have a matching hash together to save space. This can
    #       either run routinely (i.e. trigger by systemd-timer), or be activated
    #       whenever a gickup@<slug>.service finishes. The latter is probably better.

    # systemd.services."gickup-hardlink" = {
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = let
    #       script = pkgs.writeShellApplication {
    #         name = "gickup-hardlink-files.sh";
    #         runtimeInputs = [ pkgs.coreutils pkgs.jdupes ];
    #         text = ''

    #         '';
    #       };
    #     in lib.getExe script;

    #     User = "gickup";
    #     Group = "gickup";

    #     BindPaths = lib.optionals (cfg.dataDir != "/var/lib/gickup") [
    #       "${cfg.dataDir}:/var/lib/gickup"
    #     ];

    #     Slice = "system-gickup.slice";

    #     StateDirectory = "gickup";

    #     # Hardening options
    #     # TODO:
    #     PrivateNetwork = true;
    #   };
    # };
  };
}
