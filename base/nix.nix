{ lib, config, pkgs, inputs, ... }:
{
  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 2d";
    };
    optimise.automatic = true;

    settings = {
      allow-dirty = true;
      auto-allocate-uids = true;
      builders-use-substitutes = true;
      experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
      log-lines = 50;
      timeout = 24 * 60 * 60;
      use-xdg-base-directories = true;

      extra-substituters = lib.optionals (!lib.elem config.networking.hostName [ "gluttony" "wenche" ]) [
        "https://gluttony.pvv.ntnu.no"
        "https://wenche.pvv.ntnu.no"
      ];
      extra-trusted-public-keys = [
        "gluttony.pvv.ntnu.no-1:tUEtZj/8j9fmfeM7fsbg9ri9WMKoHIwExfl+q/RzfF0="
        "wenche.pvv.ntnu.no-1:7LGUoO+5UkfngJqZgc+bcPuKLtJX2+kXu3JiU3ePaZ4="
      ];
    };

    /* This makes commandline tools like
    ** nix run nixpkgs#hello
    ** and nix-shell -p hello
    ** use the same channel the system
    ** was built with
    */
    registry = lib.mkMerge [
      {
        "nixpkgs".flake = inputs.nixpkgs;
        "nixpkgs-unstable".flake = inputs.nixpkgs-unstable;
      }
      # We avoid the reference to self in vmVariant to get a stable system .outPath for equivalence testing
      (lib.mkIf (!config.virtualisation.isVmVariant) {
        "pvv-nix".flake = inputs.self;
      })
    ];
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
      "unstable=${inputs.nixpkgs-unstable}"
    ];
  };

  systemd.services.nix-gc.serviceConfig.ExecStartPre = [
    (lib.concatStringsSep " " [
      "${lib.getExe' pkgs.findutils "find"}"
      "/nix/var/nix/gcroots/auto"
      "-maxdepth 1"
      "-type l"
      "( -lname */result -o -lname */result-* )"
      "-printf 'Removing symlink %%l\\n'"
      "-delete"
    ])
  ];

  systemd.tmpfiles.settings."10-nix-stale-builds" = {
    "/nix/var/nix/builds".e.age = "2d";
  };

  nix.daemonIOSchedClass = lib.mkDefault "idle";

  systemd.services.nix-daemon.serviceConfig = {
    # Make builds to be more likely killed than important services.
    # 100 is the default for user slices and 500 is systemd-coredumpd@
    # We rather want a build to be killed than our precious user sessions as builds can be easily restarted.
    OOMScoreAdjust = lib.mkDefault 250;
    MemoryHigh = lib.mkDefault "70%";
    MemoryMax = lib.mkDefault "85%";
    # Don't swap too much, it makes things reeeally slow.
    MemorySwapMax = lib.mkDefault "10%";
    OOMPolicy = lib.mkDefault "continue";
  };
}
