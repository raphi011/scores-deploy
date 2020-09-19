terraform {
  required_providers {
    docker = {
      source = "terraform-providers/docker"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    template = {
      source = "hashicorp/template"
    }
    acme = {
      source = "terraform-providers/acme"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }

  backend "remote" {
    organization = "coding-artisan"

    workspaces {
      name = "scores"
    }
  }

  required_version = ">= 0.13"
}

provider "hcloud" {
  token = var.hetzner_api_token
}

provider "cloudflare" {
  version = "~> 2.0"
  email   = var.email_address
  api_key = var.cloudflare_api_token
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

data "template_file" "user_data" {
  template = file("./cloud-init.yaml")

  vars = {
    ssh_key = var.public_key
    ssh_user = var.ssh_user
    user    = var.scores_user
  }
}

resource "hcloud_server" "web" {
  name        = "scores"
  image       = "ubuntu-20.04"
  server_type = "cx21"
  location    = "nbg1"

  user_data = data.template_file.user_data.rendered
}

resource "hcloud_volume" "data" {
  name      = "data"
  size      = 10
  server_id = hcloud_server.web.id
  format    = "ext4"
  automount = false

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /mnt/data",
      "sudo mount ${self.linux_device} /mnt/data",
      "sudo chgrp docker /mnt/data",
      "sudo chmod g+s /mnt/data",
      "sudo mkdir -m770 /mnt/data/tls"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = var.private_key
      host        = var.scores_domain
    }
  }
}

resource "cloudflare_record" "scores" {
  zone_id = var.cloudflare_zone
  name    = var.scores_domain
  value   = hcloud_server.web.ipv4_address
  type    = "A"
  ttl     = 3600
}

resource "tls_private_key" "acme_registration" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.acme_registration.private_key_pem
  email_address   = var.email_address
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = cloudflare_record.scores.name

  dns_challenge {
    provider = "cloudflare"

    config = {
      CLOUDFLARE_API_KEY = var.cloudflare_api_token
      CLOUDFLARE_EMAIL   = var.email_address
    }
  }

  depends_on = [hcloud_volume.data]

  provisioner "file" {
    content     = acme_certificate.certificate.private_key_pem
    destination = "/mnt/data/tls/privkey.pem"

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = var.private_key
      host        = var.scores_domain
    }
  }

  provisioner "file" {
    content     = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
    destination = "/mnt/data/tls/fullchain.pem"

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = var.private_key
      host        = var.scores_domain
    }
  }
}
