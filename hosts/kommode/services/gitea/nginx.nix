{ config, lib, values, ... }:
let
  cfg = config.services.gitea;
  domain = "git.pvv.ntnu.no";

  rateLimitListFile = "/var/lib/gitea-blocklists/nginx.conf";
  fingerprintBlockListFile = "/var/lib/gitea-blocklists/fingerprints.conf";
in
{
  services.nginx.appendHttpConfig = ''
    # Group IPv6 clients by /64, IPv4 clients by /32.
    map $binary_remote_addr $gitea_scraper_key {
      "~(?s)^(?<prefix>.{8}).{8}$" $prefix;
      default $binary_remote_addr;
    }
    limit_req_zone $gitea_scraper_key zone=gitea_scrapers:64m rate=1r/s;

    geo $gitea_ratelimit_group {
      default "";
      include ${rateLimitListFile};
    }
    limit_req_zone $gitea_ratelimit_group zone=gitea_ratelimit_groups:1m rate=1r/s;

    map "${lib.concatStringsSep "\\n" [
      "proto:$server_protocol"
      "lang:$http_accept_language"
      "enc:$http_accept_encoding"
      "fetch:$http_sec_fetch_mode"
      "ua:$http_user_agent"
    ]}" $gitea_blocked_fingerprint {
      default "";
      include ${fingerprintBlockListFile};
    }

    proxy_cache_path /var/cache/nginx/gitea-assets levels=1:2 keys_zone=gitea_assets:10m max_size=1g inactive=7d use_temp_path=off;
    proxy_cache_path /var/cache/nginx/gitea-authcheck levels=1:2 keys_zone=gitea_authcheck:10m max_size=64m inactive=10m use_temp_path=off;
  '';

  # Mutable list of address ranges to rate limit. Equals group names are treated as a single group.
  # Format is: `<CIDR> <group name>;` e.g.
  #   `2a10:7b00::/29 rapidseedbox;`
  systemd.tmpfiles.settings."10-gitea-blocklists" = {
    ${dirOf rateLimitListFile}.d = {
      user = "root";
      group = "root";
      mode = "0755";
    };
    ${rateLimitListFile}.f = {
      user = "root";
      group = "root";
      mode = "0644";
    };

    # Mutable list of request fingerprints to block.
    # Use `(?m)` for `^`/`$` to match a single field, `(?ms)` with `\A(?=.*^...$)` lookaheads to match several.
    # Format is: `"~<regex>" <name>;`, e.g.
    #   `"~(?m)^ua:Lightpanda/" lightpanda;`
    #   `"~(?ms)\A(?=.*^lang:zh-CN,zh;q=0\.9,en;q=0\.8$)(?=.*^enc:gzip, deflate$)(?=.*^fetch:$)" zh-python;`
    ${fingerprintBlockListFile}.f = {
      user = "root";
      group = "root";
      mode = "0644";
    };
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;

    locations = let
      # NOTE: `satisfy any` is a bit weird, the auth requests and stuff behind will be evaluated
      #       before the `deny all` takes effect. Don't trust the order of directives as stated.
      #       Also note that the `deny all` is technically never reached because `auth_request`
      #       returns 401/403 before `deny all` becomes relevant.
      unauthenticatedFallback = fallback: ''
        satisfy any;
        allow ${values.ipv4-space};
        allow ${values.ipv6-space};
        allow ${values.ntnu.ipv4-space};
        allow ${values.ntnu.ipv6-space};
        deny all;

        auth_request /_gitea_is_authenticated;
        error_page 401 403 = ${fallback};
      '';

      fingerprintBlock = ''
        if ($gitea_blocked_fingerprint) {
          return 403;
        }
      '';

      assetCacheConfig = ''
        proxy_cache gitea_assets;
        proxy_cache_valid 200 302 6h;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        add_header X-Cache-Status $upstream_cache_status;
      '';
    in {
      "/" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = ''
          client_max_body_size 512M;
        '' + unauthenticatedFallback "@gitea_unauthenticated";
      };

      "@gitea_unauthenticated" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = fingerprintBlock + ''
          client_max_body_size 512M;
          limit_req zone=gitea_ratelimit_groups burst=10 nodelay;
          limit_req_status 429;
        '';
      };

      "= /-/ws" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        proxyWebsockets = true;
      };

      "/assets/" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = assetCacheConfig + unauthenticatedFallback "@gitea_unauthenticated_assets";
      };

      "@gitea_unauthenticated_assets" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = fingerprintBlock + assetCacheConfig + ''
          limit_req zone=gitea_ratelimit_groups burst=10 nodelay;
          limit_req_status 429;
        '';
      };

      # Throttle per-IP access to commits, raws, blames, etc.
      # This should help mitigate bot abuse to some extent.
      "~ ^/[^/]+/[^/]+/(src|raw|commits|commit|blame|archive|issues|pulls)(/|$)" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = unauthenticatedFallback "@gitea_scrape_limited";
      };

      "@gitea_scrape_limited" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = fingerprintBlock + ''
          limit_req zone=gitea_scrapers burst=5 nodelay;
          limit_req zone=gitea_ratelimit_groups burst=10 nodelay;
          limit_req_status 429;
        '';
      };

      # This is only used for rate limiting, so we ignore the Cache-Control header,
      # and cache the response for 30 seconds nonetheless.
      "= /_gitea_is_authenticated" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}:/api/v1/user";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_ignore_headers Cache-Control;
          proxy_cache gitea_authcheck;
          proxy_cache_key $http_cookie;
          proxy_cache_valid 200 401 30s;
          proxy_cache_bypass $http_authorization;
          proxy_no_cache $http_authorization;
        '';
      };

      "= /metrics" = {
        proxyPass = "http://unix:${cfg.settings.server.HTTP_ADDR}";
        extraConfig = ''
          allow ${values.hosts.ildkule.ipv4}/32;
          allow ${values.hosts.ildkule.ipv6}/128;
          deny all;
        '';
      };
    };
  };

  environment.robots-txt."gitea" = {
    virtualHosts.${domain} = true;
    enableAntiScrapingRules = true;
    rules = [
      {
        pre_comment = ''
          Gitea internals

          See these for more information:
          - https://gitea.com/robots.txt
          - https://codeberg.org/robots.txt
        '';
        User-agent = "*";
        Disallow = [
          "/api/*"
          "/avatars"
          "/*/*/src/commit/*"
          "/*/*/commit/*"
          "/*/*/commits/*"
          "/*/*/blame/*"
          "/*/*/raw/*"
          "/*/*/issues?*"
          "/*/*/pulls?*"
          "/*/*/*/refs/*"
          "/*/*/*/star"
          "/*/*/*/watch"
          "/*/*/labels"
          "/*/*/activity/*"
          "/vendor/*"
          "/swagger.*.json"
          "/repo/create"
          "/repo/migrate"
          "/org/create"
          "/*/*/fork"
          "/*/*/watchers"
          "/*/*/stargazers"
          "/*/*/forks"
          "*/.git/"
          "/*.git"
          "/*.atom"
          "/*.rss"
        ];
        Crawl-delay = "2";
      }
      {
        pre_comment = "Language Spam";
        Disallow = "/*?lang=";
      }
      {
        Sitemap = "https://${domain}/sitemap.xml";
      }
    ];
  };
}
