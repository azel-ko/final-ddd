job "registry" {
  datacenters = ["dc1"]
  type = "service"

  group "registry" {
    count = 1

    network {
      port "registry" {
        static = 5000
      }
    }

    service {
      name = "registry"
      port = "registry"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.registry.entrypoints=websecure",
        "traefik.http.routers.registry.rule=Host(`registry.${DOMAIN_NAME}`)",
        "traefik.http.routers.registry.tls.certresolver=leresolver"
      ]

      check {
        type     = "http"
        path     = "/v2/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "registry" {
      driver = "docker"

      config {
        image = "docker.1ms.run/registry:2"
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false
        ports = ["registry"]
        volumes = [
          "registry_data:/var/lib/registry"
        ]
      }

      env {
        REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY = "/var/lib/registry"
        # 允许使用不安全的 HTTP 连接，简化开发环境配置
        # 生产环境应该配置 TLS
        REGISTRY_HTTP_ADDR = "0.0.0.0:5000"
        REGISTRY_HTTP_TLS_CERTIFICATE = ""
        REGISTRY_HTTP_TLS_KEY = ""
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    volume "registry_data" {
      type      = "host"
      source    = "registry_data"
      read_only = false
    }
  }
}
