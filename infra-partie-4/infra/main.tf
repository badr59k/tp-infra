terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "net" { name = "tp_net" }

resource "docker_volume" "pg_data" { name = "tp_pg_data" }
resource "docker_volume" "redis_data" { name = "tp_redis_data" }

resource "docker_container" "postgres" {
  name  = "tp_pg"
  image = "postgres:16-alpine"
  env = [
    "POSTGRES_DB=${var.pg_database}",
    "POSTGRES_USER=${var.pg_user}",
    "POSTGRES_PASSWORD=${var.pg_password}",
  ]
  mounts {
    target = "/var/lib/postgresql/data"
    type   = "volume"
    source = docker_volume.pg_data.name
  }
  networks_advanced { name = docker_network.net.name }
}

resource "docker_container" "redis" {
  name    = "tp_redis"
  image   = "redis:7-alpine"
  command = ["redis-server", "--appendonly", "yes"]
  mounts {
    target = "/data"
    type   = "volume"
    source = docker_volume.redis_data.name
  }
  networks_advanced { name = docker_network.net.name }
}

resource "docker_image" "app" {
  name         = "tp-app:local"
  keep_locally = true
  build {
    context    = "${path.module}/../app"
    dockerfile = "Dockerfile"
    remove     = true
  }
}

resource "docker_container" "app" {
  name  = "tp_app"
  image = docker_image.app.name

  env = [
    "PORT=${var.api_port}",
    "PGHOST=${docker_container.postgres.name}",
    "PGPORT=5432",
    "PGUSER=${var.pg_user}",
    "PGPASSWORD=${var.pg_password}",
    "PGDATABASE=${var.pg_database}",
    "REDIS_HOST=${docker_container.redis.name}",
    "REDIS_PORT=6379",
  ]

  networks_advanced { name = docker_network.net.name }

  ports {
    internal = 3000
    external = var.api_port
    ip       = "0.0.0.0"
    protocol = "tcp"
  }

  depends_on = [docker_container.postgres, docker_container.redis]
}

output "api_url" { value = "http://localhost:${var.api_port}" }
