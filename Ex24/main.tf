# Define Hetzner cloud provider
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
     dns = {
      source = "hashicorp/dns"
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
  #server_url = "https://acme-v02.api.letsencrypt.org/directory"
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
    port = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

provider "dns" {
    update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "g8.key."
    key_algorithm = "hmac-sha512"
    key_secret    = file("../dns_secret.key") 
  }
}

resource "dns_a_record_set" "apex" {
  zone      = "${var.dnsZone}."
  addresses = [hcloud_server.helloServer.ipv4_address]
  ttl       = 10
}

resource "dns_a_record_set" "subdomains" {
  count = length(distinct(var.serverNames))
  zone  = "${var.dnsZone}."
  name  = var.serverNames[count.index]
  addresses = [hcloud_server.helloServer.ipv4_address]
  ttl       = 10
}

resource "tls_private_key" "cert_key" {
  algorithm   = "RSA"
}

resource "tls_private_key" "account_key" {
  algorithm = "RSA"
}

resource "tls_private_key" "ssh_key" {
  algorithm   = "ED25519"
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
    private_key_pem = indent(6, tls_private_key.cert_key.private_key_pem)
    certificate_pem = indent(6, acme_certificate.certificate.certificate_pem)
  })
  filename        = "gen/userData.yml"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.account_key.private_key_pem
  email_address   = "nobody@examples.com"
}

resource "tls_cert_request" "cert_req" {
  private_key_pem = tls_private_key.cert_key.private_key_pem

  subject {
    common_name = var.dnsZone
  }

  dns_names = ["*.${var.dnsZone}"]
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  certificate_request_pem   = tls_cert_request.cert_req.cert_request_pem

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
