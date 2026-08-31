# Define Hetzner cloud provider
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    acme = {
      source  = "vancluever/acme"
    }    
  }
  required_version = ">= 0.13"
}

# Configure the Hetzner Cloud API token
provider "hcloud" {
  token = file("../providertoken.key")
}

provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

resource "hcloud_firewall" "sshFw" {
  name = "my-firewall"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol = "tcp"
    port = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm   = "ED25519"
}
resource "tls_private_key" "cert_key" {
  algorithm   = "RSA"
}

resource "hcloud_ssh_key" "loginUser" {
  name       = var.loginUserName
  public_key = file("~/.ssh/id_ed25519.pub")
}

module "createSshKnownHosts" {
  source = "../Modules/SshKnownHosts"
  ip = hcloud_server.helloServer.ipv4_address
  loginUserName = hcloud_ssh_key.loginUser.name
  serverHostPublicKey = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "user_data" {
  content         = templatefile("tpl/userData.yml", {
    host_ed25519_private = indent(4, tls_private_key.ssh_key.private_key_openssh)
    host_ed25519_public  = indent(4, tls_private_key.ssh_key.public_key_openssh)
    devopsUsername = hcloud_ssh_key.loginUser.name
  })
  filename        = "gen/userData.yml"
}

resource "local_file" "private_key" {
  content  = tls_private_key.cert_key.private_key_pem
  filename = "./gen/private.pem"
}

resource "local_file" "certificate" {
  content  = acme_certificate.certificate.certificate_pem
  filename = "./gen/certificate.pem"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.cert_key.private_key_pem
  email_address   = "nobody@examples.com"
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = var.dnsZone
  subject_alternative_names = [ "*.${var.dnsZone}"]

  dns_challenge {
    provider = "rfc2136"

    config = {
      RFC2136_NAMESERVER     = "ns1.sdi.hdm-stuttgart.cloud"
      RFC2136_TSIG_ALGORITHM = "hmac-sha512"
      RFC2136_TSIG_KEY       = "g8.key."
      RFC2136_TSIG_SECRET    = file("../dns_secret.key")
    }
  }
}

# Create a server
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        = "debian-12"
  server_type  = "cx22"   
  location     = "nbg1"
  firewall_ids = [hcloud_firewall.sshFw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
}
