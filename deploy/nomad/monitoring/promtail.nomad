job "promtail" {
  datacenters = ["dc1"]
  type        = "system"  # 在每个节点运行

  group "promtail" {
    network {
      port "http" {
        static = 9080
      }
    }

    task "promtail" {
      driver = "docker"

      config {
        image = "grafana/promtail:2.9.0"
        ports = ["http"]
        
        args = [
          "-config.file=/etc/promtail/config.yml",
        ]

        volumes = [
          "local/promtail-config.yml:/etc/promtail/config.yml",
          "/var/log:/var/log:ro",
          "/opt/data:/opt/data:ro",
        ]
      }

      template {
        data = <<EOH
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://{{ range service "loki" }}{{ .Address }}:{{ .Port }}{{ end }}/loki/api/v1/push

scrape_configs:
  # 系统日志
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  # Nomad 日志
  - job_name: nomad
    static_configs:
      - targets:
          - localhost
        labels:
          job: nomad
          __path__: /opt/nomad/data/alloc/*/alloc/logs/*.std*

  # 应用日志
  - job_name: applications
    static_configs:
      - targets:
          - localhost
        labels:
          job: applications
          __path__: /opt/data/app/logs/*.log

  # Docker 容器日志
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'

pipeline_stages:
  # JSON 日志解析
  - json:
      expressions:
        level: level
        timestamp: time
        message: msg
        service: service
        
  # 时间戳解析
  - timestamp:
      source: timestamp
      format: RFC3339Nano
      
  # 标签提取
  - labels:
      level:
      service:
      stream:
EOH
        destination = "local/promtail-config.yml"
      }

      service {
        name = "promtail"
        port = "http"
        
        tags = [
          "logging",
          "promtail",
        ]

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
