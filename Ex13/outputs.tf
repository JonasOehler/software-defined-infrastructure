# Output variable definitions

output "instance_ip_addr" {
  value = hcloud_server.helloServer.ipv4_address
}

output "instance_name" {
  value = hcloud_server.helloServer.name
}
