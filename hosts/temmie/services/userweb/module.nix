{ config, lib, pkgs, ... }:
let
  cfg = config.services.pvv-userweb;
in
{
  options.services.pvv-userweb = {
    enable = lib.mkEnableOption "" // {
      default = true;
    };

    debugMode = lib.mkEnableOption "";

    apacheLogProcessorPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./apache-log-processor { };
    };

    homeLetters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "a" "b" "c" "d" "h" "i" "j" "k" "l" "m" "z" ];
      readOnly = true;
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = _: [ ];
    };

    php.extensions = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
    };

    php.options = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        display_errors = "Off";
        display_startup_errors = "Off";
        post_max_size = "40M";
        upload_max_filesize = "40M";
      };
      apply = attrs: lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${v}") attrs);
    };

    # https://nixos.org/manual/nixpkgs/stable/#ssec-php-user-guide-installing-with-extensions
    php.env = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.php.buildEnv {
        extensions = cfg.php.extensions;
        extraConfig = cfg.php.options;
      };
    };

    perl.packages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
    };

    perl.env = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = (pkgs.perl.withPackages cfg.perl.packages).overrideAttrs (prev: {
        # NOTE: `pkgs.perl.propagatedBuildInputs` don't actually propagate through the
        #       wrapper derivation created by `withPackages`. This should compensate
        #       for that.
        postBuild = prev.postBuild + ''
          cp -r '${pkgs.perl}/nix-support' "$out"/nix-support
        '';
      });
    };

    python3.packages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
    };

    python3.env = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.python3.buildEnv.override {
        extraLibs = cfg.python3.packages pkgs.python3Packages;
        ignoreCollisions = true;
      };
    };

    fhsEnv = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = let

      in pkgs.buildEnv {
        name = "userweb-env";
        ignoreCollisions = true;
        paths = with pkgs; [
          bash
          config.services.bro.instances.userweb-sendmail.client.package
          cfg.perl.env
          cfg.python3.env
          cfg.php.env
        ] ++ cfg.packages;

        extraOutputsToInstall = [
          "man"
          "doc"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.pvv-userweb.packages = lib.mkIf cfg.debugMode (with pkgs; [
     glibc.getent
     strace
     systemd
   ]);
  };
}
