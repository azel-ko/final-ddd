job "frontend" {
  datacenters = ["dc1"]
  type = "service"

  group "frontend" {
    count = 1

    network {
      port "http" {
        to = 80
      }
    }

    service {
      name = "frontend"
      port = "http"

      # 使用具体的域名而不是通配符
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.frontend.entrypoints=websecure",
        "traefik.http.routers.frontend.rule=Host(`${DOMAIN_NAME}`)",
        "traefik.http.routers.frontend.priority=1",
        "traefik.http.routers.frontend.tls.certresolver=leresolver"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "frontend" {
      driver = "docker"

      config {
        image = "${FRONTEND_IMAGE}"
        ports = ["http"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
      }

      # 使用模板获取后端服务地址
      template {
        data = <<EOF
# 服务发现配置
REACT_APP_API_URL=https://${DOMAIN_NAME}/app
EOF
        destination = "local/service-discovery.env"
        env = true
      }

      env {
        DOMAIN_NAME = "${DOMAIN_NAME}"
      }

      resources {
        cpu    = 300
        memory = 256
      }
    }
  }
}
