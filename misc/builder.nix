{ ... }:

{
  nix.settings.trusted-users = [ "@nix-builder-users" ];
  nix.daemonCPUSchedPolicy = "batch";

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
  ];
}
