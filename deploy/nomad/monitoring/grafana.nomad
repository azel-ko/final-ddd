job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      port "http" {
        static = 3000
      }
    }

    volume "grafana-data" {
      type      = "host"
      source    = "grafana-data"
      read_only = false
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:10.2.0"
        ports = ["http"]
        
        volumes = [
          "local/grafana.ini:/etc/grafana/grafana.ini",
          "local/datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml",
          "local/dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml",
        ]
      }

      volume_mount {
        volume      = "grafana-data"
        destination = "/var/lib/grafana"
      }

      template {
        data = <<EOH
[server]
http_port = 3000
domain = grafana.${DOMAIN_NAME}
root_url = https://grafana.${DOMAIN_NAME}

[security]
admin_user = ${GRAFANA_ADMIN_USER}
admin_password = ${GRAFANA_ADMIN_PASSWORD}

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false

[log]
mode = console
level = info

[panels]
disable_sanitize_html = false

[plugins]
allow_loading_unsigned_plugins = ""
EOH
        destination = "local/grafana.ini"
      }

      template {
        data = <<EOH
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://{{ range service "loki" }}{{ .Address }}:{{ .Port }}{{ end }}
    isDefault: true
    editable: true
    
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://{{ range service "prometheus" }}{{ .Address }}:{{ .Port }}{{ end }}
    isDefault: false
    editable: true
EOH
        destination = "local/datasources.yml"
      }

      template {
        data = <<EOH
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOH
        destination = "local/dashboards.yml"
      }

      service {
        name = "grafana"
        port = "http"
        
        tags = [
          "monitoring",
          "grafana",
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.${DOMAIN_NAME}`)",
          "traefik.http.routers.grafana.tls=true",
          "traefik.http.routers.grafana.tls.certresolver=letsencrypt",
        ]

        check {
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "3s"
        }
      }

      env {
        GF_SECURITY_ADMIN_USER     = "${GRAFANA_ADMIN_USER}"
        GF_SECURITY_ADMIN_PASSWORD = "${GRAFANA_ADMIN_PASSWORD}"
        GF_INSTALL_PLUGINS         = "grafana-piechart-panel"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
