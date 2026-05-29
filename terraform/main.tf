terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "mywebapp" {
  name = "mywebapp-pool"
  type = "dir"
  target = {
    path = var.pool_path
  }
}

resource "libvirt_volume" "base" {
  name = "ubuntu-base.qcow2"
  pool = libvirt_pool.mywebapp.name
  target = {
    format = {
      type = "qcow2"
    }
  }
  create = {
    content = {
      url = "file://${var.ubuntu_image_path}"
    }
  }
}

resource "libvirt_volume" "worker" {
  name     = "worker.qcow2"
  pool     = libvirt_pool.mywebapp.name
  capacity = 10737418240
  target = {
    format = {
      type = "qcow2"
    }
  }
  backing_store = {
    path = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_volume" "db" {
  name     = "db.qcow2"
  pool     = libvirt_pool.mywebapp.name
  capacity = 10737418240
  target = {
    format = {
      type = "qcow2"
    }
  }
  backing_store = {
    path = libvirt_volume.base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_network" "mywebapp" {
  name      = "mywebapp-net"
  autostart = true
  forward = {
    mode = "nat"
  }
  ips = [{
    address = "192.168.100.1"
    netmask = "255.255.255.0"
    dhcp    = {}
  }]
}

resource "libvirt_cloudinit_disk" "worker" {
  name = "worker-cloudinit.iso"
  meta_data = yamlencode({
    instance-id    = "worker"
    local-hostname = "worker"
  })
  user_data = templatefile("${path.module}/cloud-init/worker.yml", {
    ssh_public_key = var.ssh_public_key
  })
}

resource "libvirt_cloudinit_disk" "db" {
  name = "db-cloudinit.iso"
  meta_data = yamlencode({
    instance-id    = "db"
    local-hostname = "db"
  })
  user_data = templatefile("${path.module}/cloud-init/db.yml", {
    ssh_public_key = var.ssh_public_key
  })
}

resource "libvirt_domain" "worker" {
  name   = "worker"
  type   = "kvm"
  memory = 2097152
  vcpu   = 2

  os = {
    type         = "hvm"
    type_arch    = "aarch64"
    type_machine = "virt"
    firmware     = "efi"
  }

  devices = {
    disks = [
      {
        target = {
          dev = "vda"
          bus = "virtio"
        }
        source = {
          volume = {
            pool   = libvirt_pool.mywebapp.name
            volume = libvirt_volume.worker.name
          }
        }
      },
      {
        device = "cdrom"
        target = {
          dev = "sda"
          bus = "scsi"
        }
        source = {
          file = {
            file = libvirt_cloudinit_disk.worker.path
          }
        }
      }
    ]
    interfaces = [
      {
        source = {
          network = {
            network = libvirt_network.mywebapp.name
          }
        }
        model = {
          type = "virtio"
        }
        wait_for_ip = {}
      }
    ]
    consoles = [
      {
        target = {
          type = "serial"
          port = "0"
        }
      }
    ]
  }
}

resource "libvirt_domain" "db" {
  name   = "db"
  type   = "kvm"
  memory = 2097152
  vcpu   = 2

  os = {
    type         = "hvm"
    type_arch    = "aarch64"
    type_machine = "virt"
    firmware     = "efi"
  }

  devices = {
    disks = [
      {
        target = {
          dev = "vda"
          bus = "virtio"
        }
        source = {
          volume = {
            pool   = libvirt_pool.mywebapp.name
            volume = libvirt_volume.db.name
          }
        }
      },
      {
        device = "cdrom"
        target = {
          dev = "sda"
          bus = "scsi"
        }
        source = {
          file = {
            file = libvirt_cloudinit_disk.db.path
          }
        }
      }
    ]
    interfaces = [
      {
        source = {
          network = {
            network = libvirt_network.mywebapp.name
          }
        }
        model = {
          type = "virtio"
        }
        wait_for_ip = {}
      }
    ]
    consoles = [
      {
        target = {
          type = "serial"
          port = "0"
        }
      }
    ]
  }
}
