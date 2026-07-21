{ config, lib, pkgs, values, ... }:
let
  cfg = config.services.postgresql;
in
{
  imports = [
    ./backup.nix
    ./cleanup-timers.nix
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
    extensions = ps: with ps; [ pg_repack ];
    enableTCPIP = true;

    # NOTE: md5 accepts both md5 and scram-sha-256
    authentication = ''
      host all all ${values.ipv4-space} md5
      host all all ${values.ipv6-space} md5
      host all all ${values.hosts.ildkule.ipv4}/32 md5
      host all all ${values.hosts.ildkule.ipv6}/32 md5
    '';

    # Hilsen https://pgconfigurator.cybertec-postgresql.com/
    settings = {
      # Connectivity
      max_connections = 500;
      superuser_reserved_connections = 3;

      # Memory Settings
      shared_buffers = "8192 MB";
      work_mem = "32 MB";
      maintenance_work_mem = "420 MB";
      effective_cache_size = "22 GB";
      effective_io_concurrency = 100;
      random_page_cost = 1.25;

      # Monitoring
      shared_preload_libraries = "pg_stat_statements";
      track_io_timing = true;
      track_functions = "pl";

      # Replication
      wal_level = "replica";
      max_wal_senders = 0;
      synchronous_commit = false;

      # Checkpointing:
      checkpoint_timeout = "15 min";
      checkpoint_completion_target = 0.9;
      max_wal_size = "1024 MB";
      min_wal_size = "512 MB";

      # WAL writing
      wal_compression = true;
      wal_buffers = -1;

      # Background writer
      bgwriter_delay = "200ms";
      bgwriter_lru_maxpages = 100;
      bgwriter_lru_multiplier = 2.0;
      bgwriter_flush_after = 0;

      # Parallel queries:
      max_worker_processes = 8;
      max_parallel_workers_per_gather = 4;
      max_parallel_maintenance_workers = 4;
      max_parallel_workers = 8;
      parallel_leader_participation = true;

      # Advanced features
      enable_partitionwise_join = true;
      enable_partitionwise_aggregate = true;
      max_slot_wal_keep_size = "1000 MB";
      track_wal_io_timing = true;
      maintenance_io_concurrency = 100;
      wal_recycle = true;

      # -------------------------------- #

      # Authentication
      password_encryption = "scram-sha-256";

      # Logging
      log_connections = "authorization";
      log_disconnections = true;

      # SSL
      ssl = true;
      ssl_cert_file = "/run/credentials/postgresql.service/cert";
      ssl_key_file = "/run/credentials/postgresql.service/key";
    };
  };

  systemd.tmpfiles.settings."10-postgresql"."/data/postgresql".d = lib.mkIf cfg.enable {
    user = config.systemd.services.postgresql.serviceConfig.User;
    group = config.systemd.services.postgresql.serviceConfig.Group;
    mode = "0700";
  };

  fileSystems."/data/postgresql" = lib.mkIf cfg.enable {
    device = "/data/postgresql";
    fsType = "none";
    options = [
      "bind"
      "noatime"
      "noauto"
      "x-systemd.requires=systemd-tmpfiles-setup.service"
      "x-systemd.requires=systemd-tmpfiles-resetup.service"
    ];
  };

  systemd.services.postgresql-setup = lib.mkIf cfg.enable {
    after = [
      "systemd-tmpfiles-setup.service"
      "systemd-tmpfiles-resetup.service"
    ];
    serviceConfig = {
      LoadCredential = [
        "cert:/etc/certs/postgres.crt"
        "key:/etc/certs/postgres.key"
      ];

      RequiresMountsFor = [ "/data/postgresql" ];
      BindPaths = [ "/data/postgresql:/var/lib/postgresql" ];
    };
  };

  systemd.services.postgresql = lib.mkIf cfg.enable {
    after = [
      "systemd-tmpfiles-setup.service"
      "systemd-tmpfiles-resetup.service"
    ];
    serviceConfig = {
      LoadCredential = [
        "cert:/etc/certs/postgres.crt"
        "key:/etc/certs/postgres.key"
      ];

      RequiresMountsFor = [ "/data/postgresql" ];
      BindPaths = [ "/data/postgresql:/var/lib/postgresql" ];
    };
  };

  environment.snakeoil-certs."/etc/certs/postgres" = lib.mkIf cfg.enable {
    owner = "postgres";
    group = "postgres";
    subject = "/C=NO/O=Programvareverkstedet/CN=postgres.pvv.ntnu.no/emailAddress=drift@pvv.ntnu.no";
  };

  networking.firewall.allowedTCPPorts = lib.mkIf cfg.enable [ 5432 ];
  networking.firewall.allowedUDPPorts = lib.mkIf cfg.enable [ 5432 ];

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "postgres-update-collations.sh";
      runtimeInputs = [
        config.systemd.package
        cfg.package
      ];
      text = ''
        run0 --user=postgres psql <${pkgs.writeText "postgres-update-collations.sql" ''
          CREATE FUNCTION exec(text) returns text language plpgsql volatile
            AS $f$
              BEGIN
                EXECUTE $1;
                RETURN $1;
              END;
          $f$;

          SELECT exec('ALTER DATABASE "' || datname || '" REFRESH COLLATION VERSION') FROM pg_database WHERE datistemplate = false;
        ''}
      '';
    })
  ];
}
