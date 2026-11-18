{ config, pkgs, lib, ... }:
let
  cfg = config.services.roundcube;
  domain = "webmail.pvv.ntnu.no";
in
{
  sops.secrets."roundcube/postgres_password" = {
    owner = "nginx";
    group = "nginx";
    restartUnits = [ "phpfpm-roundcube.service" ];
  };
  sops.secrets."roundcube/des_key" = {
    owner = "nginx";
    group = "nginx";
    restartUnits = [ "phpfpm-roundcube.service" ];
  };

  services.roundcube = {
    enable = true;

    package = pkgs.roundcube.withPlugins (plugins: with plugins; [
      contextmenu
      custom_from
      persistent_login
      thunderbird_labels
    ]);

    plugins = [
      "contextmenu"
      "custom_from"
      "persistent_login"
      "thunderbird_labels"

      # Bundled with roundcube
      "archive"
      "attachment_reminder"
      "vcard_attachments"
      "zipdownload"
    ];

    dicts = with pkgs.aspellDicts; [ en nb nn fr de it ];
    maxAttachmentSize = 20;
    hostName = domain;

    database = {
      host = "postgres.pvv.ntnu.no";
      passwordFile = config.sops.secrets."roundcube/postgres_password".path;
    };


    extraConfig = let
      phpFormat = pkgs.formats.php { };

      # See https://github.com/roundcube/roundcubemail/blob/master/config/defaults.inc.php
      settings = {
        imap_host = "ssl://imap.pvv.ntnu.no:993";
        smtp_host = "ssl://smtp.pvv.ntnu.no:465";
        mail_domain = "pvv.ntnu.no";
        log_logins = true;
        des_key = phpFormat.lib.mkRaw "trim(file_get_contents('${config.sops.secrets."roundcube/des_key".path}'))";
        ifpl_use_auth_tokens = true;
      };
    in ''
      $config = array_merge($config, require '${phpFormat.generate "roundcube-pvv-config.php" settings}');
    '';
  };

  services.phpfpm.pools.roundcube.settings = {
    "pm.max_children" = 4;
    "pm.max_spare_servers" = 4;
  };

  systemd.services."phpfpm-roundcube" = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  # TODO: move this back to `webmail.pvv.ntnu.no/roundcube` subpath

  services.nginx.virtualHosts.${domain} = {
    kTLS = true;
  };
}
