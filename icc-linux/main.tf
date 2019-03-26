provider "vsphere" {
  version              = "~> 1.5"
  allow_unverified_ssl = "true"
}

provider "random" {
  version = "~> 1.0"
}

provider "local" {
  version = "~> 1.1"
}

provider "null" {
  version = "~> 1.0"
}

provider "tls" {
  version = "~> 1.0"
}

resource "random_string" "random-dir" {
  length  = 8
  special = false
}

resource "tls_private_key" "generate" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "null_resource" "create-temp-random-dir" {
  provisioner "local-exec" {
    command = "${format("mkdir -p  /tmp/%s" , "${random_string.random-dir.result}")}"
  }
}
resource "vsphere_virtual_machine" "vm" {
  // count = "${var.count}"

  name             = "${var.vm_name}"
  folder           = "${var.vm_folder}"
  num_cpus         = "${var.vm_vcpu}"
  memory           = "${var.vm_memory}"
  resource_pool_id = "${data.vsphere_resource_pool.vsphere_resource_pool.id}"
  datastore_id     = "${data.vsphere_datastore.vsphere_datastore.id}"
  guest_id         = "${data.vsphere_virtual_machine.vm_template.guest_id}"
  scsi_type        = "${data.vsphere_virtual_machine.vm_template.scsi_type}"
  #random           = "${random_string.random-dir.result}"

  clone {
    template_uuid = "${data.vsphere_virtual_machine.vm_template.id}"
    timeout = "${var.vm_clone_timeout}"
    customize {
      linux_options {
        domain    = "${var.vm_domain}"
        host_name = "${var.vm_name}"
      }

      network_interface {
        ipv4_address = "${var.vm_ipv4_address}"
        ipv4_netmask = "${var.vm_ipv4_prefix_length}"
      }

      ipv4_gateway    = "${var.vm_ipv4_gateway}"
      //dns_suffix_list = "${var.vm_dns_suffixes}"
      dns_server_list = "${var.vm_dns_servers}"
    }
  }

  network_interface {
    network_id   = "${data.vsphere_network.vm_network.id}"
    adapter_type = "${var.vm_adapter_type}"
  }

  disk {
    label          = "${var.vm_name}.vmdk"
    size           = "${var.vm_disk1_size}"
    keep_on_remove = "${var.vm_disk1_keep_on_remove}"
    datastore_id   = "${data.vsphere_datastore.vsphere_datastore.id}"
  }

  // module "Setup_ssh_master" {
  //   source = "../../modules/ssh_keygen"
  //     os_admin_user = "${var.vm_os_user}"
  //     os_password = "${var.vm_os_password}"
  //     vm_private_ssh_key = "${var.vm_private_ssh_key}"
  //     vm_public_ssh_key = "${var.vm_public_ssh_key}"
  // }
  # Specify the connection
  connection {
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"      
  }

  provisioner "local-exec" {
    #command = "echo \"${self.clone.0.customize.0.network_interface.0.ipv4_address}       ${self.name}.${var.vm_domain} ${self.name}\" >> /tmp/${var.random}/hosts"
    command = "echo \"${self.clone.0.customize.0.network_interface.0.ipv4_address}       ${self.name}.${var.vm_domain} ${self.name}\""
  }
}

resource "null_resource" "vm-create_done" {
  depends_on = ["vsphere_virtual_machine.vm"]

  provisioner "local-exec" {
    command = "echo 'VM creates done for ${var.vm_name}.'"
  }
}