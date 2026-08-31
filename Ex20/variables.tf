variable "loginUserName" {
  type = string
}

variable "dnsZone" {
  type = string
}

variable "serverName" {
  type = string
}

variable "serverAliases" {
  type = list(string)
  validation {
    condition = !contains(var.serverAliases, var.serverName)
    error_message = "serverAliases can't contain serverName"
  }
}