resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUserName
    ip = var.ip 
  })
  filename        = "bin/ssh"
  file_permission = "755"
  depends_on      = [local_file.known_hosts]
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUserName
    ip = var.ip
  })
  filename        = "bin/scp"
  file_permission = "755"
  depends_on      = [local_file.known_hosts]
}

resource "local_file" "known_hosts" {
  content =  "${var.ip} ${var.serverHostPublicKey}"
  filename        = "gen/known_hosts"
  file_permission = "644"
}