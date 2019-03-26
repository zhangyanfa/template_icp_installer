provider "vsphere" {
  version              = "~> 1.3"
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

module "deployVM_master" {
  source = "git::https://github.com/IBM-CAMHub-Open/template_icp_modules.git?ref=2.2//vmware_provision"

  #######
  vsphere_datacenter    = "${var.vsphere_datacenter}"
  vsphere_resource_pool = "${var.vsphere_resource_pool}"

  # count                 = "${length(var.master_vm_ipv4_address)}"
  count = "${length(keys(var.master_hostname_ip))}"

  #######
  // vm_folder = "${module.createFolder.folderPath}"

  vm_vcpu = "${var.master_vcpu}" // vm_number_of_vcpu
  # vm_name                    = "${var.master_prefix_name}"
  vm_name                    = "${keys(var.master_hostname_ip)}"
  vm_memory                  = "${var.master_memory}"
  vm_template                = "${var.vm_template}"
  vm_os_password             = "${var.vm_os_password}"
  vm_os_user                 = "${var.vm_os_user}"
  vm_domain                  = "${var.vm_domain}"
  vm_folder                  = "${var.vm_folder}"
  vm_private_ssh_key         = "${length(var.icp_private_ssh_key) == 0 ? "${tls_private_key.generate.private_key_pem}"     : "${var.icp_private_ssh_key}"}"
  vm_public_ssh_key          = "${length(var.icp_public_ssh_key)  == 0 ? "${tls_private_key.generate.public_key_openssh}"  : "${var.icp_public_ssh_key}"}"
  vm_network_interface_label = "${var.vm_network_interface_label}"
  vm_ipv4_gateway            = "${var.master_vm_ipv4_gateway}"
  # vm_ipv4_address            = "${var.master_vm_ipv4_address}"
  vm_ipv4_address         = "${values(var.master_hostname_ip)}"
  vm_ipv4_prefix_length   = "${var.master_vm_ipv4_prefix_length}"
  vm_adapter_type         = "${var.vm_adapter_type}"
  vm_disk1_size           = "${var.master_vm_disk1_size}"
  vm_disk1_datastore      = "${var.vm_disk1_datastore}"
  vm_disk1_keep_on_remove = "${var.master_vm_disk1_keep_on_remove}"
  vm_disk2_enable         = "${var.master_vm_disk2_enable}"
  vm_disk2_size           = "${var.master_vm_disk2_size}"
  vm_disk2_datastore      = "${var.vm_disk2_datastore}"
  vm_disk2_keep_on_remove = "${var.master_vm_disk2_keep_on_remove}"
  vm_dns_servers          = "${var.vm_dns_servers}"
  vm_dns_suffixes         = "${var.vm_dns_suffixes}"
  vm_clone_timeout        = "${var.vm_clone_timeout}"
  random                  = "${random_string.random-dir.result}"
  
}
