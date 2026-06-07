{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.prometheus.exporters.sql;
  configFile =
    if cfg.configFile != null then
      cfg.configFile
    else
      let
        nameInline = lib.mapAttrsToList (k: v: v // { name = k; });
        renameStartupSql = j: removeAttrs (j // { startup_sql = j.startupSql; }) [ "startupSql" ];
        configuration = {
          jobs = map renameStartupSql (
            nameInline (lib.mapAttrs (k: v: (v // { queries = nameInline v.queries; })) cfg.configuration.jobs)
          );
        };
      in
      builtins.toFile "config.yaml" (builtins.toJSON configuration);
in
{
  sops.secrets."config/postgresql_dibbler_password" = { };

  services.prometheus.scrapeConfigs = [
    {
      job_name = "sql_exporter";
      scrape_interval = "1m";
      scheme = "http";

      static_configs = [
        {
          targets = [ "localhost:9237" ];
        }
      ];
    }
  ];

  services.prometheus.exporters.sql = {
    enable = true;
    configuration = {
      jobs.dibbler = {
        interval = "1m";

        queries."daily_purchase_sum" = {
          help = "Sum of purchases for the current day.";
          labels = [ "thing" ];
          values = [ "sum" ];
          query = "SELECT SUM(price) FROM purchases GROUP BY DATE(time) ORDER BY DATE(time) DESC LIMIT 1";
        };

        queries."total_purchase_sum" = {
          help = "Sum of all purchases.";
          labels = [ "thing" ];
          values = [ "sum" ];
          query = "SELECT SUM(price) FROM purchases";
        };

        queries."total_stock_value" = {
          help = "The value of all stock in dibbler.";
          labels = [ "thing" ];
          values = [ "sum" ];
          query = "SELECT SUM(price * stock) FROM products";
        };

        queries."user_credit_sum" = {
          help = "The sum of all user credit.";
          labels = [ "thing" ];
          values = [ "sum" ];
          query = "SELECT SUM(credit) FROM users";
        };
      };
    };
  };

  systemd.services."prometheus-sql-exporter".serviceConfig = {
    RuntimeDirectory = "prometheus-sql-exporter";
    LoadCredential = "postgresql_dibbler_password:${
      config.sops.secrets."config/postgresql_dibbler_password".path
    }";
    ExecStartPre = ''
      |${lib.getExe pkgs.jq} \
      --null-input \
      --compact-output \
      --slurpfile config '${configFile}' \
      --rawfile pw '%d/postgresql_dibbler_password' \
      --from-file '${pkgs.writeText "prometheus-sql-exec-start-jq-filter" ''
        ("postgres://pvv_vv:\($pw | gsub("\n"; ""))@postgres.pvv.ntnu.no") as $pg_uri
        | $config[0]
        | .jobs[0].connections[0] = $pg_uri
      ''}' > /run/prometheus-sql-exporter/config.yaml
    '';
  };
}
