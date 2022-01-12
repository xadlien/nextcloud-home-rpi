terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_volume" "nextcloud_app_data" {
  name = "nextcloud_app_data"
}

resource "docker_volume" "nextcloud_db_data" {
  name = "nextcloud_db_data"
}