{ ... }:

{
  nix.settings.trusted-users = [ "@nix-builder-users" ];
  nix.daemonCPUSchedPolicy = "batch";
}
