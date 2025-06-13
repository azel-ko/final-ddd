job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1

    # 固定在有存储的节点
    constraint {
      attribute = "${node.class}"
      value     = "storage"
    }

    network {
      port "http" {
        static = 3100
      }
      port "grpc" {
        static = 9095
      }
    }

    volume "loki-data" {
      type      = "host"
      source    = "loki-data"
      read_only = false
    }

    task "loki" {
      driver = "docker"

      config {
        image = "grafana/loki:2.9.0"
        ports = ["http", "grpc"]
        
        args = [
          "-config.file=/etc/loki/local-config.yaml",
        ]

        volumes = [
          "local/loki-config.yaml:/etc/loki/local-config.yaml",
        ]
      }

      volume_mount {
        volume      = "loki-data"
        destination = "/loki"
      }

      template {
        data = <<EOH
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9095

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

# 限制查询
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 32
  max_query_parallelism: 32

# 表管理器
table_manager:
  retention_deletes_enabled: true
  retention_period: 336h  # 14 days
EOH
        destination = "local/loki-config.yaml"
      }

      service {
        name = "loki"
        port = "http"
        
        tags = [
          "logging",
          "loki",
          "traefik.enable=true",
          "traefik.http.routers.loki.rule=Host(`loki.${DOMAIN_NAME}`)",
          "traefik.http.routers.loki.tls=true",
          "traefik.http.routers.loki.tls.certresolver=letsencrypt",
        ]

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
