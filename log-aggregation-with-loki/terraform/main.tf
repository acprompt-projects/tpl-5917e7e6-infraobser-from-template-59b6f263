terraform {
  required_version = ">= 1.3.0"
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}

provider "docker" {}

resource "docker_network" "observability" {
  name = "observability-net"
}

resource "docker_volume" "loki_data" {
  name = "loki-data"
}

resource "docker_container" "loki" {
  name  = "loki"
  image = "grafana/loki:2.9.4"
  ports {
    internal = 3100
    external = 3100
  }
  volumes {
    volume_name    = docker_volume.loki_data.name
    container_path = "/loki"
  }
  upload {
    content = templatefile("${path.module}/loki-config.yml", {
      chunk_idle_period = "5m"
      max_chunk_age     = "1h"
    })
    file = "/etc/loki/local-config.yaml"
  }
  networks_advanced {
    name = docker_network.observability.name
  }
  restart = "unless-stopped"
  command  = ["-config.file=/etc/loki/local-config.yaml"]
}

resource "docker_container" "promtail" {
  name  = "promtail"
  image = "grafana/promtail:2.9.4"
  volumes {
    host_path      = "/var/log"
    container_path = "/var/log"
    read_only      = true
  }
  volumes {
    host_path      = "/var/lib/docker/containers"
    container_path = "/var/lib/docker/containers"
    read_only      = true
  }
  upload {
    content = templatefile("${path.module}/promtail-config.yml", {
      loki_url = "http://loki:3100/loki/api/v1/push"
    })
    file = "/etc/promtail/config.yml"
  }
  networks_advanced {
    name = docker_network.observability.name
  }
  restart = "unless-stopped"
  command  = ["-config.file=/etc/promtail/config.yml"]
}

output "loki_endpoint" {
  value = "http://localhost:${docker_container.loki.ports[0].external}"
}