{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.environment.snakeoil-certs;
in
{
  options.environment.snakeoil-certs = lib.mkOption {
    default = { };
    description = "Self signed certs, which are rotated regularly";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0660";
            };
            daysValid = lib.mkOption {
              type = lib.types.str;
              default = "90";
            };
            extraOpenSSLArgs = lib.mkOption {
              type = with lib.types; listOf str;
              default = [ ];
            };
            certificate = lib.mkOption {
              type = lib.types.str;
              default = "${name}.crt";
            };
            certificateKey = lib.mkOption {
              type = lib.types.str;
              default = "${name}.key";
            };
            subject = lib.mkOption {
              type = lib.types.str;
              default = "/C=NO/O=Programvareverkstedet/CN=*.pvv.ntnu.no/emailAddress=drift@pvv.ntnu.no";
            };
          };
        }
      )
    );
  };

  config = {
    systemd.services."generate-snakeoil-certs" = {
      enable = true;
      serviceConfig.Type = "oneshot";
      script =
        let
          openssl = lib.getExe pkgs.openssl;
        in
        lib.concatMapStringsSep "\n" (
          { name, value }:
          ''
            mkdir -p $(dirname "${value.certificate}") $(dirname "${value.certificateKey}")
            if ! ${openssl} x509 -checkend 86400 -noout -in ${value.certificate}
            then
              echo "Regenerating '${value.certificate}'"
              ${openssl} req \
                -newkey rsa:4096 \
                -new -x509 \
                -days "${toString value.daysValid}" \
                -nodes \
                -subj "${value.subject}" \
                -out "${value.certificate}" \
                -keyout "${value.certificateKey}" \
                ${lib.escapeShellArgs value.extraOpenSSLArgs}
            fi
            chown "${value.owner}:${value.group}" "${value.certificate}"
            chown "${value.owner}:${value.group}" "${value.certificateKey}"
            chmod "${value.mode}" "${value.certificate}"
            chmod "${value.mode}" "${value.certificateKey}"

            echo "\n-----------------\n"
          ''
        ) (lib.attrsToList cfg);
    };
    systemd.timers."generate-snakeoil-certs" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";
        Persistent = true;
        Unit = "generate-snakeoil-certs.service";
      };
    };
  };
}
