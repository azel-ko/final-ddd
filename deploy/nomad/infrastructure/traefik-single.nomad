job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 1

    # 网络配置 - 单机模式使用 host 网络
    network {
      mode = "host"
    }

    service {
      name = "traefik"
      port = 80

      check {
        name     = "traefik-health"
        type     = "tcp"
        port     = 80
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v3.0"
        network_mode = "host"
        force_pull = false

        volumes = [
          "local/acme.json:/etc/traefik/acme.json",
          "local/dynamic.yml:/etc/traefik/dynamic/dynamic.yml"
        ]

        mount {
          type   = "bind"
          source = "/opt/data/traefik"
          target = "/logs"
        }

        args = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--providers.file.directory=/etc/traefik/dynamic",
          "--providers.file.watch=true",
          "--entrypoints.web.address=:80",
          "--entrypoints.websecure.address=:443",
          "--entrypoints.traefik.address=:8080",
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

      # 创建动态配置文件
      template {
        data = <<EOF
http:
  routers:
    app:
      rule: "Host(`${DOMAIN_NAME}`)"
      entryPoints:
        - websecure
      service: app
      tls:
        certResolver: letsencrypt
    app-http:
      rule: "Host(`${DOMAIN_NAME}`)"
      entryPoints:
        - web
      middlewares:
        - redirect-to-https
      service: app

  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true

  services:
    app:
      loadBalancer:
        servers:
          - url: "http://localhost:8080"
EOF
        destination = "local/dynamic.yml"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
