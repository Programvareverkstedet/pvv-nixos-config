{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.prometheus.exporters.sql;
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

      metric_relabel_configs = [
        {
          source_labels = [ "__name__" ];
          regex = "sql_(dibbler_.*)";
          target_label = "__name__";
          replacement = "$1";
        }
      ];
    }
  ];

  # TODO: consider baking all of these queries into some sort of stats endpoint
  #       in the dibbler software itself.
  services.prometheus.exporters.sql = {
    enable = true;
    configuration = {
      jobs.dibbler = {
        interval = "1m";

        queries."dibbler_total_stock_value" = {
          help = "The value of all stock in dibbler.";
          values = [ "sum" ];
          query = "SELECT SUM(price * stock) FROM products";
        };

        queries."dibbler_user_credit_sum" = {
          help = "The sum of all user credit.";
          values = [ "sum" ];
          query = "SELECT SUM(credit) FROM users";
        };

        queries."dibbler_user_count" = {
          help = "Number of registered users.";
          values = [ "count" ];
          query = "SELECT COUNT(*) AS count FROM users";
        };

        queries."dibbler_product_count" = {
          help = "Number of non-hidden products.";
          values = [ "count" ];
          query = ''
            SELECT COUNT(*) AS count
            FROM products
            WHERE NOT hidden
          '';
        };

        queries."dibbler_out_of_stock_products" = {
          help = "Number of non-hidden products that are out of stock.";
          values = [ "count" ];
          query = ''
            SELECT COUNT(*) AS count
            FROM products
            WHERE stock <= 0 AND NOT hidden
          '';
        };

        queries."dibbler_debtor_count" = {
          help = "Number of users with negative credit.";
          values = [ "count" ];
          query = ''
            SELECT COUNT(*) AS count
            FROM users
            WHERE credit < 0
          '';
        };

        queries."dibbler_total_user_debt" = {
          help = "Sum of credit across users with negative credit only.";
          values = [ "sum" ];
          query = ''
            SELECT COALESCE(SUM(credit), 0) AS sum
            FROM users
            WHERE credit < 0
          '';
        };

        queries."dibbler_products_flow_by_day" = {
          help = "Products sold and added, grouped by day, for the last 30 days.";
          labels = [ "day" ];
          values = [ "sold" "added" ];
          query = ''
            SELECT
              DATE(p.time)::text AS day,
              COALESCE(-SUM(CASE WHEN pe.amount > 0 THEN pe.amount ELSE 0 END), 0) AS sold,
              COALESCE(-SUM(CASE WHEN pe.amount < 0 THEN pe.amount ELSE 0 END), 0) AS added
            FROM purchase_entries pe
            JOIN purchases p ON pe.purchase_id = p.id
            WHERE p.time >= CURRENT_DATE - INTERVAL '29 days'
            GROUP BY DATE(p.time)
            ORDER BY day
          '';
        };

        queries."dibbler_top_selling_products" = {
          help = "Top 20 products by units sold all time.";
          labels = [ "product" "product_id" ];
          values = [ "sum" ];
          query = ''
            SELECT p.name AS product, p.product_id::text AS product_id, SUM(pe.amount) AS sum
            FROM purchase_entries pe
            JOIN products p ON pe.product_id = p.product_id
            WHERE pe.amount > 0
            GROUP BY p.product_id, p.name
            ORDER BY sum DESC
            LIMIT 20
          '';
        };

        queries."dibbler_product_stock_levels" = {
          help = "Current stock level per product.";
          labels = [ "product" "product_id" ];
          values = [ "stock" ];
          query = ''
            SELECT name AS product, product_id::text AS product_id, stock
            FROM products
            WHERE NOT hidden AND stock != 0
          '';
        };
      };
    };
  };

  systemd.services."prometheus-sql-exporter".serviceConfig = {
    RuntimeDirectory = "prometheus-sql-exporter";
    LoadCredential = "postgresql_dibbler_password:${
      config.sops.secrets."config/postgresql_dibbler_password".path
    }";
    ExecStartPre = let
      jqFilter = pkgs.writeText "prometheus-sql-exec-start-jq-filter" ''
        ("postgres://pvv_vv:\($pw | gsub("\n"; ""))@postgres.pvv.ntnu.no") as $pg_uri
        | $config[0]
        | .jobs[0].connections[0] = $pg_uri
      '';

      configFile =
        if cfg.configFile != null
          then cfg.configFile
          else let
            nameInline = lib.mapAttrsToList (k: v: v // { name = k; });
            renameStartupSql = j: removeAttrs (j // { startup_sql = j.startupSql; }) [ "startupSql" ];
            configuration = {
              jobs = map renameStartupSql (
                nameInline (lib.mapAttrs (k: v: (v // { queries = nameInline v.queries; })) cfg.configuration.jobs)
              );
            };
          in builtins.toFile "config.yaml" (builtins.toJSON configuration);
    in ''
      |${lib.getExe pkgs.jq} \
      --null-input \
      --compact-output \
      --slurpfile config '${configFile}' \
      --rawfile pw '%d/postgresql_dibbler_password' \
      --from-file '${jqFilter}' \
      > /run/prometheus-sql-exporter/config.yaml
    '';
    ExecStart = lib.mkForce ''
      ${lib.getExe pkgs.prometheus-sql-exporter} \
        -web.listen-address ${config.services.prometheus.exporters.sql.listenAddress}:${toString config.services.prometheus.exporters.sql.port} \
        -config.file /run/prometheus-sql-exporter/config.yaml
    '';
  };
}
