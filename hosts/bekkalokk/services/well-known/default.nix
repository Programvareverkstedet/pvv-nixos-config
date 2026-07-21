{ lib, ... }:
{
  # TODO: move this to base so that all virtualHosts take effect on their respecitve hosts

  # NOTE: automatically hosting well-known files by looping over all existing `virtualHosts`
  #       unfortunately causes infinite recursuion due to submodule usage within the nginx
  #       module. For now, the easiest solution was to manually specify a list of virtualHosts
  #       here, but it would be nice to find a better solution in the future.
  services.nginx.virtualHosts = lib.mkMerge [
    (lib.genAttrs [
      "pvv.ntnu.no"
      "pvv.org"

      "www.pvv.ntnu.no"
      "www.pvv.org"
      "www2.pvv.ntnu.no"
      "www2.pvv.org"

      # NOTE: this list is probably not complete
      "alps.pvv.ntnu.no"
      "chat.pvv.ntnu.no"
      "grafana.pvv.ntnu.no"
      "status.pvv.ntnu.no"
      "matrix.pvv.ntnu.no"
      "mirrors.pvv.ntnu.no"
      "pages.pvv.ntnu.no"
      "ooye.pvv.ntnu.no"
      "ooye.pvv.ntnu.no"
      "dav.pvv.ntnu.no"
      "git.pvv.ntnu.no"
      "idp.pvv.ntnu.no"
      "minecraft.pvv.ntnu.no"
      "pw.pvv.ntnu.no"
      "snappymail.pvv.ntnu.no"
      "webmail.pvv.ntnu.no"
      "wiki.pvv.ntnu.no"
    ] (_: {
      locations."^~ /.well-known/security.txt" = {
        alias = toString ./root/security.txt;
      };
    }))

    (lib.genAttrs [
      "pvv.ntnu.no"
      "pvv.org"
      "mail.pvv.ntnu.no"
      "mail.pvv.org"
      "smtp.pvv.ntnu.no"
      "smtp.pvv.org"
    ] (_: {
      locations."^~ /.well-known/autoconfig/mail/" = {
        root = toString ./root/autoconfig/mail;
      };
    }))

    (lib.genAttrs [
      "pvv.ntnu.no"
      "pvv.org"
      "www.pvv.ntnu.no"
      "www.pvv.org"
    ] (_: {
      locations."^~ /.well-known/matrix/" = {
        extraConfig = ''
          proxy_set_header Host matrix.pvv.ntnu.no;
          proxy_pass https://matrix.pvv.ntnu.no/.well-known/matrix/;
        '';
      };
    }))
  ];
}
