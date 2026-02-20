{
  config,
  unstablePkgs,
  lib,
  ...
}:
let
  cfg = config.services.gitea-actions-runner;
in
{
  config.topology.self.services = lib.mapAttrs' (name: instance: {
    name = "gitea-runner-${name}";
    value = {
      name = "Gitea runner ${name}";
      icon = "services.gitea";
    };
  }) (lib.filterAttrs (_: instance: instance.enable) cfg.instances);
}
