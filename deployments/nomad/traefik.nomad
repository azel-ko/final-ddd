job "traefik" {
  datacenters = ["dc1"]
  type = "service"

  # 移除所有 constraint 块

  group "traefik" {
    count = 1

    host_volume "traefik-data" { # For logs and potentially other data like acme.json if configured to be stored in a directory
      path      = "/opt/data/traefik"
      read_only = false
    }

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
        network_mode = "host" # network_mode = "host" means ports are directly mapped.
        # Ports are listed for clarity but are effectively host ports.
        ports = ["http", "https" ,"api"]
        # 告诉 Nomad 不要从远程仓库拉取镜像
        force_pull = false

        volumes = [
          # acme.json for Let's Encrypt certificates.
          # "local/acme.json" implies it's managed within the alloc dir or a predefined local path.
          # If it needs to be on a shared host path, it should be explicitly defined.
          # For now, we assume 'local/' is specific to the task runner context.
          # Update: The problem description decided to keep this as is.
          "local/acme.json:/etc/traefik/acme.json",
          # Traefik logs
          "/opt/data/traefik:/logs", # This now implicitly uses the host_volume "traefik-data"
        ]

        args = [
          "--api.dashboard=true",
          "--api.insecure=true", # Insecure for dashboard, consider securing this in production
          "--providers.nomad=true",
          "--providers.nomad.exposedByDefault=false", # Services must opt-in via tags
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.websecure.address=:${NOMAD_PORT_https}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_api}", # For Traefik API/dashboard
          "--certificatesresolvers.leresolver.acme.email=your-email@example.com", # Placeholder
          "--certificatesresolvers.leresolver.acme.storage=/etc/traefik/acme.json",
          "--certificatesresolvers.leresolver.acme.tlschallenge=true",
          "--log.level=DEBUG", # Or INFO, ERROR
          "--log.filepath=/logs/traefik.log",
          "--accesslog=true",
          "--accesslog.filepath=/logs/access.log",
          "--accesslog.bufferingsize=100"
        ]
      }

      # Template for acme.json to ensure it exists with correct permissions
      # This is useful if "local/acme.json" means a file created by this template.
      template {
        data = "{}" # Empty JSON file, Traefik will populate it
        destination = "local/acme.json"
        perms = "600" # Restrictive permissions for certificate file
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
