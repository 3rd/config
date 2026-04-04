{
  cfg,
  dataDir,
}:
let
  retention = "${toString cfg.retention.lokiDays}d";
in {
  auth_enabled = false;

  server = {
    http_listen_address = "127.0.0.1";
    http_listen_port = cfg.ports.loki;
    grpc_listen_address = "127.0.0.1";
    grpc_listen_port = 9096;
  };

  common = {
    instance_addr = "127.0.0.1";
    path_prefix = dataDir;
    replication_factor = 1;
    ring.kvstore.store = "inmemory";
    storage.filesystem = {
      chunks_directory = "${dataDir}/chunks";
      rules_directory = "${dataDir}/rules";
    };
  };

  schema_config.configs = [
    {
      from = "2024-01-01";
      store = "tsdb";
      object_store = "filesystem";
      schema = "v13";
      index = {
        prefix = "index_";
        period = "24h";
      };
    }
  ];

  storage_config.tsdb_shipper = {
    active_index_directory = "${dataDir}/tsdb-index";
    cache_location = "${dataDir}/tsdb-cache";
  };

  query_range.results_cache.cache.embedded_cache = {
    enabled = true;
    max_size_mb = 128;
  };

  frontend.encoding = "protobuf";

  compactor = {
    working_directory = "${dataDir}/compactor";
    compaction_interval = "10m";
    retention_enabled = true;
    delete_request_store = "filesystem";
  };

  limits_config = {
    retention_period = retention;
    max_query_lookback = retention;
    reject_old_samples = true;
    reject_old_samples_max_age = retention;
    ingestion_rate_mb = 16;
    ingestion_burst_size_mb = 32;
    per_stream_rate_limit = "5MB";
    per_stream_rate_limit_burst = "20MB";
  };

  analytics.reporting_enabled = false;
}
