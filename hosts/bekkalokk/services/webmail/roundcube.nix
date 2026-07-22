{ config, pkgs, lib, ... }:

with lib;
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
      persistent_login
      thunderbird_labels
      contextmenu
      custom_from
    ]);

    dicts = with pkgs.aspellDicts; [ en en-computers nb nn fr de it ];
    maxAttachmentSize = 20;
    hostName = domain;

    database = {
      host = "postgres.pvv.ntnu.no";
      passwordFile = config.sops.secrets."roundcube/postgres_password".path;
    };

    extraConfig = ''
      $config['enable_installer'] = false;
      $config['default_host'] = "ssl://imap.pvv.ntnu.no";
      $config['default_port'] = 993;
      $config['smtp_server'] = "ssl://smtp.pvv.ntnu.no";
      $config['smtp_port'] = 465;
      $config['mail_domain'] = "pvv.ntnu.no";
      $config['smtp_user'] = "%u";
      $config['support_url'] = "";
      $config['des_key'] = "${config.sops.secrets."roundcube/des_key".path}";
    '';
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
