{ config, pkgs, lib, ... }:

let
  inherit (lib) mkDefault mkEnableOption mkForce mkIf mkOption mkPackageOption generators types;

  cfg = config.services.snappymail;
  maxUploadSize = "256M";
in {
  options.services.snappymail = {
    enable = mkEnableOption "Snappymail";

    package = mkPackageOption pkgs "snappymail" { };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/snappymail";
      description = "State directory for snappymail";
    };

    hostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "mail.example.com";
      description = "Enable nginx with this hostname, null disables nginx";
    };

    user = mkOption {
      type = types.str;
      default = "snappymail";
      description = "System user under which snappymail runs";
    };

    group = mkOption {
      type = types.str;
      default = "snappymail";
      description = "System group under which snappymail runs";
    };
  };

  config = mkIf cfg.enable {
    users.users = mkIf (cfg.user == "snappymail") {
      snappymail = {
        description = "Snappymail service";
        group = cfg.group;
        home = cfg.dataDir;
        isSystemUser = true;
      };
    };

    users.groups = mkIf (cfg.group == "snappymail") {
      snappymail = {};
    };

    services.phpfpm.pools.snappymail = {
      user = cfg.user;
      group = cfg.group;
      phpOptions = generators.toKeyValue {} {
        upload_max_filesize = maxUploadSize;
        post_max_size = maxUploadSize;
        memory_limit = maxUploadSize;
      };

      settings = {
        "listen.owner" = config.services.nginx.user;
        "listen.group" = config.services.nginx.group;
        "pm" = "ondemand";
        "pm.max_children" = 32;
        "pm.process_idle_timeout" = "10s";
        "pm.max_requests" = 500;
      };
    };

    services.nginx = mkIf (cfg.hostname != null) {
      virtualHosts."${cfg.hostname}" = {
        locations."/".extraConfig = ''
          index index.php;
          autoindex on;
          autoindex_exact_size off;
          autoindex_localtime on;
        '';
        locations."^~ /data".extraConfig = ''
          deny all;
        '';
        locations."~ \\.php$".extraConfig = ''
          include ${config.services.nginx.package}/conf/fastcgi_params;

          fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;
          fastcgi_pass unix:${config.services.phpfpm.pools.snappymail.socket};
        '';
        extraConfig = ''
          client_max_body_size ${maxUploadSize};
        '';

        root = if (cfg.package == pkgs.snappymail) then
          pkgs.snappymail.override {
            dataPath = cfg.dataDir;
          }
        else cfg.package;
      };
    };
  };
}

