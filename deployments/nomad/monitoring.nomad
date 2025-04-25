job "monitoring" {
  datacenters = ["dc1"]
  type = "service"

  group "prometheus" {
    count = 1

    network {
      port "prometheus_ui" {
        static = 9090
      }
    }

    service {
      name = "prometheus"
      port = "prometheus_ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=Host(`prometheus.service.consul`)",
        "traefik.http.services.prometheus.loadbalancer.server.port=9090"
      ]

      check {
        type     = "http"
        path     = "/-/healthy"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "docker.1ms.run/prom/prometheus:latest"
        ports = ["prometheus_ui"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
          "prometheus_data:/prometheus"
        ]
      }

      template {
        data = <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'nomad_metrics'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['nomad-client', 'nomad']

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

  - job_name: 'app'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['app']
EOF
        destination = "local/prometheus.yml"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    volume "prometheus_data" {
      type      = "host"
      source    = "prometheus_data"
      read_only = false
    }
  }

  group "grafana" {
    count = 1

    network {
      port "grafana_ui" {
        static = 3000
      }
    }

    service {
      name = "grafana"
      port = "grafana_ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.service.consul`)",
        "traefik.http.services.grafana.loadbalancer.server.port=3000"
      ]

      check {
        type     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "docker.1ms.run/grafana/grafana:latest"
        ports = ["grafana_ui"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        volumes = [
          "grafana_data:/var/lib/grafana",
          "local/provisioning:/etc/grafana/provisioning"
        ]
      }

      env {
        GF_SECURITY_ADMIN_USER = "${GRAFANA_ADMIN_USER}"
        GF_SECURITY_ADMIN_PASSWORD = "${GRAFANA_ADMIN_PASSWORD}"
        GF_SERVER_ROOT_URL = "https://grafana.azel.icu"
      }

      template {
        data = <<EOF
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  access: proxy
  url: http://{{ env "NOMAD_IP_grafana_ui" }}:9090
  isDefault: true
EOF
        destination = "local/provisioning/datasources/datasource.yml"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    volume "grafana_data" {
      type      = "host"
      source    = "grafana_data"
      read_only = false
    }
  }
}
