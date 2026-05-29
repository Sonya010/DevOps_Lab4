terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "mywebapp" {
  name = "mywebapp-pool"
  type = "dir"
  path = var.pool_path
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-base.qcow2"
  pool   = libvirt_pool.mywebapp.name
  source = var.ubuntu_image_path
  format = "qcow2"
}

resource "libvirt_volume" "worker" {
  name           = "worker.qcow2"
  pool           = libvirt_pool.mywebapp.name
  base_volume_id = libvirt_volume.base.id
  size           = 10737418240
}

resource "libvirt_volume" "db" {
  name           = "db.qcow2"
  pool           = libvirt_pool.mywebapp.name
  base_volume_id = libvirt_volume.base.id
  size           = 10737418240
}

resource "libvirt_network" "mywebapp" {
  name      = "mywebapp-net"
  mode      = "nat"
  addresses = ["192.168.100.0/24"]
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled = true
  }
}

resource "libvirt_cloudinit_disk" "worker" {
  name      = "worker-cloudinit.iso"
  pool      = libvirt_pool.mywebapp.name
  user_data = templatefile("${path.module}/cloud-init/worker.yml", {
    ssh_public_key = var.ssh_public_key
  })
}

resource "libvirt_cloudinit_disk" "db" {
  name      = "db-cloudinit.iso"
  pool      = libvirt_pool.mywebapp.name
  user_data = templatefile("${path.module}/cloud-init/db.yml", {
    ssh_public_key = var.ssh_public_key
  })
}

resource "libvirt_domain" "worker" {
  name   = "worker"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.worker.id

  disk {
    volume_id = libvirt_volume.worker.id
  }

  network_interface {
    network_id     = libvirt_network.mywebapp.id
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource "libvirt_domain" "db" {
  name   = "db"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.db.id

  disk {
    volume_id = libvirt_volume.db.id
  }

  network_interface {
    network_id     = libvirt_network.mywebapp.id
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
