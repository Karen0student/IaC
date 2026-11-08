terraform {
  required_version = ">= 1.6.0"

  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = "~> 2.0.1"
    }
  }
}

provider "multipass" {
  command_timeout = 600
}

variable "ssh_public_key_path" {
  description = "SSH public key path"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

locals {
  admin_public_key = trimspace(
    file(pathexpand(var.ssh_public_key_path))
  )

  vms = {
    tf-vm01 = {
      image = "https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
      cpus   = 8
      memory = "4G"
      disk   = "20G"

      packages = [
        "curl",
        "ca-certificates",
        "ufw"
      ]

      commands = [
        "/bin/bash /usr/local/sbin/install-docker.sh",
        "ufw allow OpenSSH",
        "ufw --force enable",
      ]
    }

    tf-vm02 = {
      image = "file:///var/snap/multipass/common/resolute-server-cloudimg-amd64.img"
      cpus   = 8
      memory = "4G"
      disk   = "10G"

      packages = [
        "prometheus-node-exporter",
        "ufw"
      ]

      commands = [
        "systemctl enable --now prometheus-node-exporter",
        "ufw allow OpenSSH",
        "ufw --force enable",
      ]
    }
  }

  cloud_init = {
    for name, vm in local.vms : name => yamlencode(merge(
      {
        hostname         = name
        manage_etc_hosts = true

        users = [
          {
            name                = "admin"
            primary_group       = "sudo"
            groups              = ["sudo"]
            no_user_group       = true
            sudo                = "ALL=(ALL) NOPASSWD:ALL"
            shell               = "/bin/bash"
            lock_passwd         = true
            ssh_authorized_keys = [local.admin_public_key]
          }
        ]

        ssh_pwauth      = false
        package_update  = true
        package_upgrade = true
        packages        = vm.packages

        runcmd = vm.commands
      },

      name == "tf-vm01" ? {
        write_files = [
          {
            path        = "/usr/local/sbin/install-docker.sh"
            owner       = "root:root"
            permissions = "0755"
            content     = file("${path.module}/scripts/install-docker.sh")
          }
        ]
      } : {}
    ))
  }
}

resource "multipass_instance" "vm" {
  for_each = local.vms

  name   = each.key
  image  = each.value.image
  cpus   = each.value.cpus
  memory = each.value.memory
  disk   = each.value.disk

  cloud_init = local.cloud_init[each.key]

  wait_for_cloud_init = true

  timeouts {
    create = "20m"
  }
}

output "vm_names" {
  description = "Terraform-managed VMs"
  value       = [for vm in multipass_instance.vm : vm.name]
}

output "vm_ips" {
  description = "IPv4 addresses of the virtual machines"

  value = {
    for name, vm in multipass_instance.vm :
    name => try(vm.ipv4[0], null)
  }
}
