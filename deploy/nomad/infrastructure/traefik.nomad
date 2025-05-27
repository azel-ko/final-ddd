job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 1

    # 数据持久化
    host_volume "traefik-data" {
      path      = "/opt/data/traefik"
      read_only = false
    }

    # 网络配置 - 集群模式
    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "http"

      check {
        name     = "traefik-health"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v3.0"
        ports = ["http", "https", "api"]
        force_pull = false

        volumes = [
          "local/acme.json:/etc/traefik/acme.json",
          "/opt/data/traefik:/logs"
        ]

        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--providers.nomad=true",
          "--providers.nomad.exposedByDefault=false",
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.websecure.address=:${NOMAD_PORT_https}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_api}",
          "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}",
          "--certificatesresolvers.letsencrypt.acme.storage=/etc/traefik/acme.json",
          "--certificatesresolvers.letsencrypt.acme.tlschallenge=true",
          "--log.level=INFO",
          "--log.filepath=/logs/traefik.log",
          "--accesslog=true",
          "--accesslog.filepath=/logs/access.log"
        ]
      }

      # 创建 ACME 证书文件
      template {
        data = "{}"
        destination = "local/acme.json"
        perms = "600"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
