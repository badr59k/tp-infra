terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "stack_net" {
  name = "catalogue_net"
}


resource "docker_volume" "pg_data" {
  name = "pg_data"
}

resource "docker_volume" "redis_data" {
  name = "redis_data"
}

resource "docker_container" "postgres" {
  name  = "pg16"
  image = "postgres:16-alpine"

  env = [
    "POSTGRES_DB=catalogue",
    "POSTGRES_USER=app",
    "POSTGRES_PASSWORD=appsecret"
  ]

  networks_advanced { name = docker_network.stack_net.name }

  mounts {
    target = "/var/lib/postgresql/data"
    type   = "volume"
    source = docker_volume.pg_data.name
  }
}

resource "docker_container" "redis" {
  name    = "redis7"
  image   = "redis:7-alpine"
  command = ["redis-server", "--appendonly", "yes"]

  networks_advanced { name = docker_network.stack_net.name }

  mounts {
    target = "/data"
    type   = "volume"
    source = docker_volume.redis_data.name
  }
}

resource "docker_image" "api" {
  name = "catalogue-api:stable"
  build {
    context    = "${path.module}/api"
    dockerfile = "Dockerfile"
  }
  keep_locally = true
}

resource "docker_container" "api" {
  name  = "catalogue-api"
  image = docker_image.api.image_id

  env = [
    "PORT=${var.api_port}",
    "PGHOST=pg16",
    "PGUSER=${var.pg_user}",
    "PGPASSWORD=${var.pg_password}",
    "PGDATABASE=${var.pg_db}",
    "PGPORT=5432",
    "REDIS_HOST=redis7",
    "REDIS_PORT=6379"
  ]

  networks_advanced { name = docker_network.stack_net.name }

  ports {
    internal = 3000
    external = var.api_port
  }

  depends_on = [docker_container.postgres, docker_container.redis]
}

output "api_url" {
  value = "http://localhost:${var.api_port}"
}