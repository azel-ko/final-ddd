terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
}

# 创建 Droplet
resource "digitalocean_droplet" "calculator_server" {
  image  = "ubuntu-20-04-x64"
  name   = "calculator-service"
  region = "nyc3"
  size   = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.example.id]
}

# 创建防火墙
resource "digitalocean_firewall" "calculator_firewall" {
  name = "calculator-firewall"

  droplet_ids = [digitalocean_droplet.calculator_server.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0"]
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.calculator_server.ipv4_address
}