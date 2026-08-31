# Define Hetzner cloud provider
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
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

resource "tls_private_key" "host" {
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
  serverHostPublicKey = tls_private_key.host.public_key_openssh
}

resource "local_file" "user_data" {
  content         = templatefile("tpl/userData.yml", {
    host_ed25519_private = indent(4, tls_private_key.host.private_key_openssh)
    host_ed25519_public  = indent(4, tls_private_key.host.public_key_openssh)
    devopsUsername = hcloud_ssh_key.loginUser.name
    volId = hcloud_volume.vol01.id
  })
  filename        = "gen/userData.yml"
}
 
resource "hcloud_volume" "vol01" {
  name      = "vol01"
  size      = 10
  format    = "xfs"
  location = "nbg1"
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

resource "hcloud_volume_attachment" "main" {
  volume_id=hcloud_volume.vol01.id
  server_id=hcloud_server.helloServer.id
  automount = false
}