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
  };

  services.roundcube = {
    enable = true;

    package = pkgs.roundcube.withPlugins (plugins: with plugins; [
      persistent_login
      thunderbird_labels
      contextmenu
      custom_from
    ]);

    dicts = with pkgs.aspellDicts; [ en en-science en-computers nb nn fr de it ];
    maxAttachmentSize = 20;
    hostName = "roundcubeplaceholder.example.com";

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
    '';
  };

  services.nginx.virtualHosts."roundcubeplaceholder.example.com" = lib.mkForce { };

  services.nginx.virtualHosts.${domain} = {
    kTLS = true;
    locations."/roundcube" = {
      tryFiles = "$uri $uri/ =404";
      index = "index.php";
      root = pkgs.runCommandLocal "roundcube-dir" { } ''
        mkdir -p $out
        ln -s ${cfg.package} $out/roundcube
      '';
      extraConfig = ''
        location ~ ^/roundcube/(${builtins.concatStringsSep "|" [
        # https://wiki.archlinux.org/title/Roundcube
        "README"
        "INSTALL"
        "LICENSE"
        "CHANGELOG"
        "UPGRADING"
        "bin"
        "SQL"
        ".+\\.md"
        "\\."
        "config"
        "temp"
        "logs"
        ]})/? {
          deny all;
        }

        location ~ ^/roundcube/(.+\.php)(/?.*)$ {
          fastcgi_split_path_info ^/roundcube(/.+\.php)(/.+)$;
          include ${config.services.nginx.package}/conf/fastcgi_params;
          include ${config.services.nginx.package}/conf/fastcgi.conf;
          fastcgi_index index.php;
          fastcgi_pass unix:${config.services.phpfpm.pools.roundcube.socket};
        }
      '';
    };
  };
}
