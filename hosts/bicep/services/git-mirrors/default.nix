{ config, pkgs, lib, fp, ... }:
let
  cfg = config.services.gickup;
in
{
  sops.secrets."gickup/github-token" = {
    owner = "gickup";
  };

  services.gickup = {
    enable = true;

    dataDir = "/data/gickup";

    destinationSettings = {
      structured = true;
      zip = false;
      keep = 10;
      bare = true;
      lfs = false;
    };

    instances = let
      defaultGithubConfig = {
        settings.token_file = config.sops.secrets."gickup/github-token".path;
      };
      defaultGitlabConfig = {
        # settings.token_file = ...
      };
    in {
      "github:Git-Mediawiki/Git-Mediawiki" = defaultGithubConfig;
      "github:NixOS/nixpkgs" = defaultGithubConfig;
      "github:go-gitea/gitea" = defaultGithubConfig;
      "github:heimdal/heimdal" = defaultGithubConfig;
      "github:saltstack/salt" = defaultGithubConfig;
      "github:typst/typst" = defaultGithubConfig;
      "github:unmojang/FjordLauncher" = defaultGithubConfig;
      "github:unmojang/drasl" = defaultGithubConfig;
      "github:yushijinhun/authlib-injector" = defaultGithubConfig;

      "gitlab:mx-puppet/discord/better-discord.js" = defaultGitlabConfig;
      "gitlab:mx-puppet/discord/discord-markdown" = defaultGitlabConfig;
      "gitlab:mx-puppet/discord/matrix-discord-parser" = defaultGitlabConfig;
      "gitlab:mx-puppet/discord/mx-puppet-discord" = defaultGitlabConfig;
      "gitlab:mx-puppet/mx-puppet-bridge" = defaultGitlabConfig;

      "any:glibc" = {
        settings.url = "https://sourceware.org/git/glibc.git";
      };

      "any:out-of-your-element" = {
        settings.url = "https://gitdab.com/cadence/out-of-your-element.git";
      };

      "any:out-of-your-element-module" = {
        settings.url = "https://cgit.rory.gay/nix/OOYE-module.git";
      };
    };
  };

  services.cgit = let
    domain = "bicep.pvv.ntnu.no";
  in {
    ${domain} = {
      enable = true;
      package = pkgs.callPackage (fp /packages/cgit.nix) { };
      group = "gickup";
      scanPath = "${cfg.dataDir}/linktree";
      settings = {
        enable-commit-graph = true;
        enable-follow-links = true;
        enable-http-clone = true;
        enable-remote-branches = true;
        clone-url = "https://${domain}/$CGIT_REPO_URL";
        remove-suffix = true;
        root-title = "PVVSPPP";
        root-desc = "PVV Speiler Praktisk og Prominent Programvare";
        snapshots = "all";
        logo = "/PVV-logo.png";
      };
    };
  };

  services.nginx.virtualHosts."bicep.pvv.ntnu.no" = {
    forceSSL = true;
    enableACME = true;

    locations."= /PVV-logo.png".alias = let
      small-pvv-logo = pkgs.runCommandLocal "pvv-logo-96x96" {
        nativeBuildInputs = [ pkgs.imagemagick ];
      } ''
        magick '${fp /assets/logo_blue_regular.svg}' -resize 96x96 PNG:"$out"
      '';
    in toString small-pvv-logo;
  };

  systemd.services."fcgiwrap-cgit-bicep.pvv.ntnu.no" = {
    serviceConfig.BindReadOnlyPaths = [ cfg.dataDir ];
  };
}
