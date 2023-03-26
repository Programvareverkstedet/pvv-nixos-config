{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host all all 127.0.0.0/8 trust
      host all all ::1/128 trust
      host all all 241.129.241.128/25
    '';

    # Hilsen https://pgconfigurator.cybertec-postgresql.com/
    settings = {
      # Connectivity
      max_connections = 500;
      superuser_reserved_connections = 3;

      # Memory Settings
      shared_buffers = "2048 MB";
      work_mem = "32 MB";
      maintenance_work_mem = "320 MB";
      effective_cache_size = "6 GB";
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
      jit = true;
      max_slot_wal_keep_size = "1000 MB";
      track_wal_io_timing = true;
      maintenance_io_concurrency = 100;
      wal_recycle = true;
    };
  };
}
