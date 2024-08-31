{ ... }:
{
  system.autoUpgrade = {
    enable = true;
    flake = "git+https://git.pvv.ntnu.no/Drift/pvv-nixos-config.git";
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "nixpkgs-unstable"
      "--no-write-lock-file"
    ];
  };
}