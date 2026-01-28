{ config, lib, pkgs, values, ... }:
let
  cfg = config.services.postgresql;
in
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;
    enableTCPIP = true;

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

  services.postgresqlBackup = lib.mkIf cfg.enable {
    enable = true;
    location = "/var/lib/postgres-backups";
    backupAll = true;
  };

  services.rsync-pull-targets = lib.mkIf cfg.enable {
    enable = true;
    locations.${config.services.postgresqlBackup.location} = {
      user = "root";
      rrsyncArgs.ro = true;
      authorizedKeysAttrs = [
        "restrict"
        "no-agent-forwarding"
        "no-port-forwarding"
        "no-pty"
        "no-X11-forwarding"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvO7QX7QmwSiGLXEsaxPIOpAqnJP3M+qqQRe5dzf8gJ postgresql rsync backup";
    };
  };
}
