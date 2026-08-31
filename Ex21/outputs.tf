# Output variable definitions

output "instance_ip_addr" {
  value = [for s in hcloud_server.helloServer : s.ipv4_address]
}

output "instance_name" {
  value = [for s in hcloud_server.helloServer : s.name]
}
