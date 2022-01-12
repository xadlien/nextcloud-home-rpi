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

# password input
variable "nextcloud_db_mysql_root_password" {  
  type = string
}

variable "nextcloud_db_mysql_password" {  
  type = string
}

# network setup
resource "docker_network" "nextcloud_network" {
    name = "nextcloud_network"
}

# images
resource "docker_image" "nextcloud" {
    name = "nextcloud"
    keep_locally = true
}

resource "docker_image" "mariadb" {
    name = "mariadb"
    keep_locally = true
}
resource "docker_image" "nextcloud_ssl" {
  name = "nextcloud_ssl"
  keep_locally = true 
  build {
    path = "."
    tag = ["nextcloud_ssl:latest"]
  }
  depends_on = [
    docker_image.nextcloud,
  ]
}

# cert creation
resource "tls_private_key" "nextcloud" {
  algorithm   = "RSA"
}
resource "tls_self_signed_cert" "nextcloud" {
  key_algorithm   = "RSA"
  private_key_pem = resource.tls_private_key.nextcloud.private_key_pem

  subject {
    common_name  = "martin.com"
    organization = "Martin Household"
  }

  validity_period_hours = 99999999999

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# cert file creation
resource "local_file" "private_key" {
    content     = resource.tls_private_key.nextcloud.private_key_pem
    filename = "${path.cwd}/secrets/private_key.pem"
}
resource "local_file" "public_key" {
    content     = resource.tls_self_signed_cert.nextcloud.cert_pem
    filename = "${path.cwd}/secrets/public_key.pem"
}

# containers
resource "docker_container" "nextcloud_mariadb" {
  image = docker_image.mariadb.latest
  name  = "nextcloud_mariadb"
  hostname = "db"
  command = ["--transaction-isolation=READ-COMMITTED", "--binlog-format=ROW", "--innodb-file-per-table=1", "--skip-innodb-read-only-compressed"]
  networks_advanced {
    name = "nextcloud_network"
  }
  volumes {
    volume_name = "nextcloud_db_data"
    container_path = "/var/lib/mysql"
  }
  env = [
      "MYSQL_ROOT_PASSWORD=${var.nextcloud_db_mysql_root_password}",
      "MYSQL_DATABASE=nextcloud",
      "MYSQL_USER=nextcloud",
      "MYSQL_PASSWORD=${var.nextcloud_db_mysql_password}"
  ]
    depends_on = [
      docker_image.mariadb,
      docker_network.nextcloud_network,
  ]
}

resource "docker_container" "nextcloud_app" {
  image = docker_image.nextcloud_ssl.latest
  name  = "nextcloud_app"
  hostname = "app"
  networks_advanced {
    name = "nextcloud_network"
  }
  ports {
    internal = 443
    external = 8080
  }
  volumes {
    volume_name = "nextcloud_app_data"
    container_path = "/var/www/html"
  }
  volumes {
    host_path = "${path.cwd}/secrets/private_key.pem"
    container_path = "/etc/ssl/private/private_key.pem"
  }
  volumes {
    host_path = "${path.cwd}/secrets/public_key.pem"
    container_path = "/etc/ssl/certs/public_key.pem"
  }
  volumes {
    host_path = "${path.cwd}/000-default.conf"
    container_path = "/etc/apache2/sites-available/000-default.conf"
  }
  env = [
      "MYSQL_PASSWORD=${var.nextcloud_db_mysql_password}",
      "MYSQL_DATABASE=nextcloud",
      "MYSQL_USER=nextcloud",
      "MYSQL_HOST=nextcloud_mariadb"
  ]
  depends_on = [
      docker_container.nextcloud_mariadb,
      docker_image.nextcloud_ssl,
      docker_network.nextcloud_network,
      tls_private_key.nextcloud,
      tls_self_signed_cert.nextcloud,
  ]
}