{ pkgs, config, secrets, inputs, ... }:
let
  jackson = pkgs.callPackage ../../../pkgs/jackson { };
in {
  systemd.services.jackson = {
    description = "Jackson";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${jackson}/bin/jackson";
      DynamicUser = true;
      Restart = "always";
    };
  };
}
