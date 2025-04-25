job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "admin" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "http"

      # 确保这些标签在 Consul 中注册
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.traefik-dashboard.entrypoints=websecure",
        "traefik.http.routers.traefik-dashboard.service=api@internal",
        "traefik.http.routers.traefik-dashboard.rule=PathPrefix(`/dash`)",
        "traefik.http.middlewares.traefik-dashboard_strip.stripprefix.prefixes=/dash",
        "traefik.http.routers.traefik-dashboard.middlewares=traefik-dashboard_strip",
        "traefik.http.routers.traefik-dashboard.tls.certresolver=leresolver",
        "traefik.http.routers.traefik-dashboard-api.entrypoints=websecure",
        "traefik.http.routers.traefik-dashboard-api.service=api@internal",
        "traefik.http.routers.traefik-dashboard-api.rule=PathPrefix(`/api`)",
        "traefik.http.routers.traefik-dashboard-api.tls.certresolver=leresolver"
      ]

      check {
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "docker.1ms.run/traefik:v2.10"
        ports = ["http", "https", "admin"]

        # 确保这些卷在所有节点上都可用
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/acme.json:/etc/traefik/acme.json",
          "local/certs:/etc/traefik/certs",
          "local/logs:/var/log/traefik"
        ]

        # 网络模式设置为 host，确保可以直接访问主机网络
        network_mode = "host"

        args = [
          "--api=true",
          "--api.dashboard=true",
          "--api.insecure=true",
          "--ping=true",
          "--entryPoints.web.address=:80",
          "--entryPoints.web.http.redirections.entryPoint.to=websecure",
          "--entryPoints.web.http.redirections.entryPoint.scheme=https",
          "--entryPoints.websecure.address=:443",

          # 配置 Consul Catalog 提供者，使用集群中的 Consul 服务
          "--providers.consulcatalog=true",
          "--providers.consulcatalog.endpoint=${NOMAD_META_CONSUL_HTTP_ADDR}",
          "--providers.consulcatalog.exposedbydefault=false",
          "--providers.consulcatalog.prefix=traefik",

          # 配置 Let's Encrypt 证书
          "--certificatesresolvers.leresolver.acme.tlschallenge=true",
          "--certificatesresolvers.leresolver.acme.email=a@163.com",
          "--certificatesresolvers.leresolver.acme.storage=/etc/traefik/acme.json",

          # 添加外部 IP 配置，确保证书验证可以正常工作
          "--entrypoints.websecure.http.tls=true"
        ]
      }

      template {
        data = <<EOF
# traefik.toml
[log]
  level = "INFO"

[accessLog]
  filePath = "/var/log/traefik/access.log"
  bufferingSize = 100

# 全局配置
[global]
  checkNewVersion = false
  sendAnonymousUsage = false

# 确保 API 和仪表板可用
[api]
  dashboard = true
  insecure = true

# 配置入口点
[entryPoints]
  [entryPoints.web]
    address = ":80"
    [entryPoints.web.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"

  [entryPoints.websecure]
    address = ":443"
    [entryPoints.websecure.http.tls]
      certResolver = "leresolver"
EOF
        destination = "local/traefik.toml"
      }

      template {
        data = ""
        destination = "local/acme.json"
        perms = "600"
      }

      # 添加 Consul 地址的环境变量
      env {
        NOMAD_META_CONSUL_HTTP_ADDR = "${attr.nomad.advertise.address}:8500"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
