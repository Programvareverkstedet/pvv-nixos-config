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

    extraConfig = ''
      $config['default_host'] = "ssl://imap.pvv.ntnu.no";
      $config['default_port'] = 993;
      $config['smtp_server'] = "ssl://smtp.pvv.ntnu.no";
      $config['smtp_port'] = 465;
      $config['mail_domain'] = "pvv.ntnu.no";
      $config['log_logins'] = true;
      $config['des_key'] = trim(file_get_contents('${config.sops.secrets."roundcube/des_key".path}'));
      $config['ifpl_use_auth_tokens'] = true;
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
