variable "ubuntu_image_path" {
  description = "Path to Ubuntu cloud image (qcow2)"
  type        = string
  default     = "/var/lib/libvirt/images/ubuntu-22.04-server-cloudimg-arm64.img"
}

variable "ssh_public_key" {
  description = "SSH public key for ansible user"
  type        = string
}

variable "pool_path" {
  description = "Path for libvirt storage pool"
  type        = string
  default     = "/var/lib/libvirt/pools/mywebapp"
}
