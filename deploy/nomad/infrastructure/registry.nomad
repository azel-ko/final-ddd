job "registry" {
  datacenters = ["dc1"]
  type = "service"

  # 集群模式下固定在特定节点运行
  constraint {
    attribute = "${node.class}"
    value     = "${REGISTRY_NODE_CLASS}"
    operator  = "="
  }

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
        "traefik.http.routers.registry.entrypoints=web",
        "traefik.http.routers.registry.rule=Host(`registry.${DOMAIN_NAME}`)"
      ]

      check {
        name     = "registry-health"
        type     = "http"
        path     = "/v2/"
        port     = "registry"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "registry" {
      driver = "docker"

      config {
        image = "registry:2"
        ports = ["registry"]
        force_pull = false

        mount {
          type   = "bind"
          source = "/opt/data/registry"
          target = "/var/lib/registry"
        }
      }

      env {
        REGISTRY_STORAGE = "filesystem"
        REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY = "/var/lib/registry"
        REGISTRY_HTTP_ADDR = "0.0.0.0:5000"
        REGISTRY_HTTP_TLS_CERTIFICATE = ""
        REGISTRY_HTTP_TLS_KEY = ""
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
