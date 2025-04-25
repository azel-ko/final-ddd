job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  # 移除所有 constraint 块

  group "traefik" {
    count = 1

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
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "docker.1ms.run/traefik:v2.10"
        network_mode = "host"
        ports = ["http", "https", "api"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false

        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--providers.nomad=true",
          "--providers.nomad.exposedByDefault=false",
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.websecure.address=:${NOMAD_PORT_https}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_api}",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
