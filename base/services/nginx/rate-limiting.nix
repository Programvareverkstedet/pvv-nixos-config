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

        exempt.addresses = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "192.0.2.1"
            "198.51.100.0/24"
            "2001:db8::/32"
          ];
          description = ''
            IP addresses/CIDR ranges that are not rate limited by this zone.
          '';
        };

        exempt.cookies = lib.mkOption {
          type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_]+");
          default = [ ];
          example = [ "SESSIONID" ];
          description = ''
            If any of the listed cookies are present in a request, it will be exempted from this zone's rate limiting.

            Even if it is easy to spoof, it *should* work against the scraper hordes.
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

    (let
      renderZone = zone: let
        hasAddresses = zone.exempt.addresses != [ ];
        hasCookies = zone.exempt.cookies != [ ];

        keyVar = "$rate_limit_key_${zone.name}";
        exemptVar = "$rate_limit_exempt_${zone.name}";

        exemptAddressVar = if hasCookies then "$rate_limit_exempt_address_${zone.name}" else exemptVar;
        exemptCookieVar = if hasAddresses then "$rate_limit_exempt_cookie_${zone.name}" else exemptVar;

        exemptAddressGeo = ''
          geo ${exemptAddressVar} {
            default 0;
          ${lib.concatMapStringsSep "\n" (address: "  ${address} 1;") zone.exempt.addresses}
          }
        '';

        exemptCookieMap = ''
          map "${lib.concatMapStrings (cookie: "$cookie_${cookie}") zone.exempt.cookies}" ${exemptCookieVar} {
            "" 0;
            default 1;
          }
        '';

        exemptAnyMap = ''
          map "${exemptAddressVar}${exemptCookieVar}" ${exemptVar} {
            "~1" 1;
            default 0;
          }
        '';

        exemptKeyMap = ''
          map ${exemptVar} ${keyVar} {
            1 "";
            default ${zone.key};
          }
        '';

        limitReqZone = key: ''
          limit_req_zone ${key} zone=${zone.name}:${zone.size} rate=${zone.rate};
        '';
      in
        if !hasAddresses && !hasCookies
        then limitReqZone zone.key
        else lib.concatStringsSep "\n" (
          lib.optional hasAddresses exemptAddressGeo
          ++ lib.optional hasCookies exemptCookieMap
          ++ lib.optional (hasAddresses && hasCookies) exemptAnyMap
          ++ [
            exemptKeyMap
            (limitReqZone keyVar)
          ]
        );
    in lib.mkIf (cfg.rateLimitZones != { }) (lib.pipe cfg.rateLimitZones [
      lib.attrValues
      (map renderZone)
      lib.concatStrings
      lib.mkAfter
    ]))
  ];
}
