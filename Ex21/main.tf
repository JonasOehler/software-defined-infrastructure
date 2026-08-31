# Define Hetzner cloud provider
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
     dns = {
      source = "hashicorp/dns"
    }
  }
  required_version = ">= 0.13"
}

# Configure the Hetzner Cloud API token
provider "hcloud" {
  token = file("../providertoken.key")
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

provider "dns" {
    update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "g8.key."
    key_algorithm = "hmac-sha512"
    key_secret    = file("../dns_secret.key") 
  }
}

resource "dns_a_record_set" "aliases" {
  count = var.serverCount
  zone  = "${var.dnsZone}."
  name  = hcloud_server.helloServer[count.index].name
  addresses = [hcloud_server.helloServer[count.index].ipv4_address]
  ttl       = 10
}

resource "hcloud_ssh_key" "loginUser" {
  name       = var.loginUserName
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "tls_private_key" "host" {
  algorithm   = "ED25519"
}

resource "local_file" "user_data" {
  count           = var.serverCount
  content         = templatefile("tpl/userData.yml", {
    host_ed25519_private = indent(4, tls_private_key.host.private_key_openssh)
    host_ed25519_public  = indent(4, tls_private_key.host.public_key_openssh)
    devopsUsername = hcloud_ssh_key.loginUser.name
  })
  filename        = "${var.serverName}${count.index+1}/gen/userData.yml"
}

resource "local_file" "known_hosts" {
  count           = var.serverCount
  content         = "${var.serverName}${count.index+1}.${var.dnsZone} ${tls_private_key.host.public_key_openssh}"
  filename        = "${var.serverName}${count.index+1}/gen/known_hosts"
  file_permission = "644"
}

resource "local_file" "ssh_script" {
  count           = var.serverCount
  content = templatefile("tpl/ssh.sh", {
    devopsUsername = hcloud_ssh_key.loginUser.name
    ip = "${var.serverName}${count.index+1}.${var.dnsZone}"
  })
  filename        = "${var.serverName}${count.index+1}/bin/ssh"
  file_permission = "755"
  depends_on      = [local_file.known_hosts]
}

resource "local_file" "scp_script" {
  count           = var.serverCount
  content = templatefile("tpl/scp.sh", {
    devopsUsername = hcloud_ssh_key.loginUser.name
    ip = "${var.serverName}${count.index+1}.${var.dnsZone}"
  })
  filename        = "${var.serverName}${count.index+1}/bin/scp"
  file_permission = "755"
  depends_on      = [local_file.known_hosts]
}

resource "hcloud_server" "helloServer" {
  count        = var.serverCount
  name         = "${var.serverName}${count.index+1}"
  image        = "debian-12"
  server_type  = "cx22"   
  user_data    = local_file.user_data[count.index].content
  firewall_ids = [hcloud_firewall.sshFw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
}