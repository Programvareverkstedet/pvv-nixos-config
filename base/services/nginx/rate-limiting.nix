{ config, lib, ... }:
let
  cfg = config.services.nginx;
in
{
  # https://blog.nginx.org/blog/rate-limiting-nginx
  # https://nginx.org/en/docs/http/ngx_http_limit_req_module.html
  options.services.nginx.rateLimitZones = lib.mkOption {
    default = { };
    example = {
      scrapers = {
        size = "10m";
        rate = "1r/s";
      };
    };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        name = lib.mkOption {
          type = lib.types.strMatching "[A-Za-z0-9_]+";
          default = name;
          defaultText = lib.literalExpression "<name>";
          description = ''
            Name of the zone.

            Will be used as `limit_req zone=<name>`.
          '';
        };

        key = lib.mkOption {
          type = lib.types.str;
          default = "$binary_remote_subnet";
          example = "$cookie_SESSIONID";
          description = ''
            Key to rate limit by.

            The default keys IPv4 by address and IPv6 by its /64 prefix.
          '';
        };
        size = lib.mkOption {
          type = lib.types.strMatching "[0-9]+[kKmM]?";
          default = "10m";
          description = ''
            Size of the shared memory zone.

            `1m` holds about 16_000 keys for `$binary_remote_addr`.
          '';
        };
        rate = lib.mkOption {
          type = lib.types.strMatching "[0-9]+r/[sm]";
          default = "1r/s";
          example = "30r/m";
          description = ''
            Max request rate per key.

           Specify requests per second (`r/s`) or minute (`r/m`).
          '';
        };
      };
    }));
  };

  config.services.nginx.appendHttpConfig = lib.mkMerge [
    ''
      # Group IPv6 clients by /64, IPv4 clients by /32.
      map $binary_remote_addr $binary_remote_subnet {
        "~(?s)^(?<prefix>.{8}).{8}$" $prefix;
        default $binary_remote_addr;
      }

      limit_req_status 429;
    ''

    (lib.mkIf (cfg.rateLimitZones != { }) (lib.pipe cfg.rateLimitZones [
      (lib.mapAttrsToList (_: zone: "limit_req_zone ${zone.key} zone=${zone.name}:${zone.size} rate=${zone.rate};"))
      lib.concatLines
      lib.mkAfter
    ]))
  ];
}
