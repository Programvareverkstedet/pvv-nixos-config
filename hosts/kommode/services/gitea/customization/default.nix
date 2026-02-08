{ config, pkgs, lib, fp, ... }:
let
  cfg = config.services.gitea;
in
{
  services.gitea-themes = {
    monokai = pkgs.gitea-theme-monokai;
    earl-grey = pkgs.gitea-theme-earl-grey;
    pitch-black = pkgs.gitea-theme-pitch-black;
    catppuccin = pkgs.gitea-theme-catppuccin;
  };

  systemd.services.gitea-customization = lib.mkIf cfg.enable {
    description = "Install extra customization in gitea's CUSTOM_DIR";
    wantedBy = [ "gitea.service" ];
    requiredBy = [ "gitea.service" ];

    serviceConfig =  {
      Type = "oneshot";
      User = cfg.user;
      Group = cfg.group;
    };

    script = let
      logo-svg = fp /assets/logo_blue_regular.svg;
      logo-png = fp /assets/logo_blue_regular.png;

      extraLinks = pkgs.writeText "gitea-extra-links.tmpl" ''
        <a class="item" href="https://git.pvv.ntnu.no/Drift/-/projects/4">Tokyo Drift Issues</a>
      '';

      extraLinksFooter = pkgs.writeText "gitea-extra-links-footer.tmpl" ''
        <a class="item" href="https://www.pvv.ntnu.no/">PVV</a>
        <a class="item" href="https://wiki.pvv.ntnu.no/">Wiki</a>
        <a class="item" href="https://wiki.pvv.ntnu.no/wiki/Tjenester/Kodelager">PVV Gitea Howto</a>
      '';

      project-labels = (pkgs.formats.yaml { }).generate "gitea-project-labels.yaml" {
        labels = lib.importJSON ./labels/projects.json;
      };

      customTemplates = pkgs.runCommandLocal "gitea-templates" {
        nativeBuildInputs = with pkgs; [
          coreutils
          gnused
        ];
      } ''
        # Bigger icons
        install -Dm444 "${cfg.package.src}/templates/repo/icon.tmpl" "$out/repo/icon.tmpl"
        sed -i -e 's/24/60/g' "$out/repo/icon.tmpl"
      '';
    in ''
      install -Dm444 ${logo-svg} "${cfg.customDir}/public/assets/img/logo.svg"
      install -Dm444 ${logo-png} "${cfg.customDir}/public/assets/img/logo.png"
      install -Dm444 ${./loading.apng} "${cfg.customDir}/public/assets/img/loading.png"
      install -Dm444 ${extraLinks} "${cfg.customDir}/templates/custom/extra_links.tmpl"
      install -Dm444 ${extraLinksFooter} "${cfg.customDir}/templates/custom/extra_links_footer.tmpl"
      install -Dm444 ${project-labels} "${cfg.customDir}/options/label/project-labels.yaml"

      "${lib.getExe pkgs.rsync}" -a "${customTemplates}/" "${cfg.customDir}/templates/"
    '';
  };
}
