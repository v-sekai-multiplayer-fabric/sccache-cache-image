packer {
  required_version = ">= 1.10"
  required_plugins {
    qemu = {
      version = "~> 1.1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "source_image_url" {
  type        = string
  description = "URL of the parent linux-base-image qcow2. Pin to an explicit release tag, never 'latest'."
  default     = "https://github.com/v-sekai-multiplayer-fabric/linux-base-image/releases/download/v0.1.0/linux-base-image.qcow2"
}

variable "source_image_checksum" {
  type        = string
  description = "Checksum of the parent image in `<algorithm>:<hex>` form. Bump in lockstep with source_image_url."
  default     = "file:https://github.com/v-sekai-multiplayer-fabric/linux-base-image/releases/download/v0.1.0/linux-base-image.qcow2.sha512"
}

variable "output_directory" {
  type    = string
  default = "../output"
}

variable "vm_name" {
  type    = string
  default = "sccache-cache-image.qcow2"
}

variable "version" {
  type        = string
  description = "Tag for the resulting image. CI passes the git ref / release tag."
  default     = "dev"
}

source "qemu" "sccache-cache" {
  iso_url      = var.source_image_url
  iso_checksum = var.source_image_checksum

  disk_image  = true
  disk_size   = "10G"
  format      = "qcow2"
  accelerator = "kvm"
  cpus        = 2
  memory      = 2048
  headless    = true

  output_directory = var.output_directory
  vm_name          = var.vm_name

  cd_files = ["./cidata/user-data", "./cidata/meta-data"]
  cd_label = "cidata"

  ssh_username         = "almalinux"
  ssh_private_key_file = "./cidata/ssh_key"
  ssh_timeout          = "10m"

  shutdown_command = "sudo shutdown -h now"

  qemuargs = [
    ["-cpu", "host"],
    ["-display", "none"],
  ]
}

build {
  name    = "sccache-cache-image-${var.version}"
  sources = ["source.qemu.sccache-cache"]

  # Quadlet files land in /etc/containers/systemd/ so podman's systemd
  # generator picks them up at boot. install.sh moves them into place.
  provisioner "shell" {
    inline = ["mkdir -p /tmp/quadlets"]
  }

  provisioner "file" {
    source      = "../configs/quadlets/"
    destination = "/tmp/quadlets/"
  }

  provisioner "shell" {
    script          = "./scripts/install.sh"
    execute_command = "sudo -E bash {{ .Path }}"
  }
}
