job "app" {
  datacenters = ["dc1"]
  type = "service"

  group "app" {
    count = 1

    # 应用日志持久化
    host_volume "app-logs" {
      path      = "/opt/data/app"
      read_only = false
    }

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name = "app"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.app.entrypoints=websecure",
        "traefik.http.routers.app.rule=Host(`${DOMAIN_NAME}`)",
        "traefik.http.routers.app.tls.certresolver=letsencrypt",
        "traefik.http.routers.app.priority=10"
      ]

      check {
        name     = "app-health"
        type     = "http"
        path     = "/api/health"
        port     = "http"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = "${APP_IMAGE}"
        ports = ["http"]
        force_pull = false

        volumes = [
          "/opt/data/app:/app/logs"
        ]
      }

      # 服务发现配置
      template {
        data = <<EOF
# 数据库连接
POSTGRES_ADDR={{ range service "postgres" }}{{ .Address }}:{{ .Port }}{{ end }}

# 应用配置
DATABASE_HOST={{ range service "postgres" }}{{ .Address }}{{ end }}
DATABASE_PORT={{ range service "postgres" }}{{ .Port }}{{ end }}
EOF
        destination = "local/service-discovery.env"
        env = true
      }

      env {
        # 应用基本配置
        APP_ENV = "${APP_ENV}"
        APP_PORT = "8080"
        
        # 数据库配置
        DB_TYPE = "postgres"
        DB_NAME = "${DB_NAME}"
        DB_USER = "${DB_USER}"
        DB_PASSWORD = "${DB_PASSWORD}"
        
        # JWT 配置
        JWT_SECRET = "${JWT_SECRET}"
        
        # 日志配置
        LOG_LEVEL = "${LOG_LEVEL}"
        LOG_FORMAT = "json"
      }

      resources {
        cpu    = 800
        memory = 768
      }

      logs {
        max_files     = 10
        max_file_size = 10
      }
    }

    ephemeral_disk {
      size = 300
    }
  }
}
