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

  connection {
    type     = "ssh"
    user     = "${var.vm_os_user}"
    password = "${var.vm_os_password}"
  }

  provisioner "file" {
    destination = "install_icp.sh"

    content = <<EOF
# =================================================================
# Licensed Materials - Property of IBM
# 5737-E67
# @ Copyright IBM Corporation 2016, 2017 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
# =================================================================
#!/bin/bash
echo "hello icp!!!!"
sudo mkdir /opt/ibm-cloud-private-3.1.2
cd /opt/ibm-cloud-private-3.1.2
sudo docker run -v $(pwd):/data -e LICENSE=accept ibmcom/icp-inception-amd64:3.1.2-ee cp -r cluster /data

sudo mkdir ./cluster/images
cp /opt/media/ibm-cloud-private-x86_64-3.1.2.tar.gz /opt/ibm-cloud-private-3.1.2/cluster/images

echo "default_admin_password: ${var.icp_admin_password}" >> ./cluster/config.yaml
echo "password_rules:" >> ./cluster/config.yaml
echo " - '(.*)'" >> ./cluster/config.yaml

echo "ansible_user: root" >> ./cluster/config.yaml
echo "ansible_ssh_pass: cbiadmin" >> ./cluster/config.yaml
echo "ansible_ssh_common_args: \"-oPubkeyAuthentication=no\"" >> ./cluster/config.yaml

echo "cluster_name: ${var.icp_cluster_name}" >> ./cluster/config.yaml
echo "cluster_CA_domain: \"{{ cluster_name }}.icp\"" >> ./cluster/config.yaml

echo "[master]" > ./cluster/hosts
echo "${var.vm_ipv4_address}" >> ./cluster/hosts
echo "[worker]" >> ./cluster/hosts
echo "${var.vm_ipv4_address}" >> ./cluster/hosts
echo "[proxy]" >> ./cluster/hosts
echo "${var.vm_ipv4_address}" >> ./cluster/hosts

cd /opt/ibm-cloud-private-3.1.2/cluster
sudo docker run --net=host -t -e LICENSE=accept -v "$(pwd)":/installer/cluster ibmcom/icp-inception-amd64:3.1.2-ee install

EOF
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "bash -c 'chmod +x install_icp.sh'",
      "bash -c './install_icp.sh  >> install_icp.log 2>&1'"
    ]
  }

  provisioner "file" {
    destination = "install_mcm.sh"

    content = <<EOF
# =================================================================
# Licensed Materials - Property of IBM
# 5737-E67
# @ Copyright IBM Corporation 2016, 2017 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
# =================================================================
#!/bin/bash
echo "hello mcm!!!!"

if [ "${var.icp_install_mcm}" == "true" -o "${var.icp_install_mcmk}" == "true" ];then
echo "${var.icp_install_mcm}"
cd /opt

docker login ${var.icp_cluster_name}.icp:8500 -u admin -p ${var.icp_admin_password}

cloudctl login -a https://${var.icp_cluster_name}.icp:8443 -u admin -p ${var.icp_admin_password} -n kube-system --skip-ssl-validation

cloudctl catalog load-ppa-archive -a /opt/media/mcm-3.1.2/mcm-ppa-3.1.2.tgz --registry ${var.icp_cluster_name}.icp:8500/kube-system

    if [ "${var.icp_install_mcm}" == "true" ];then
        wget https://${var.icp_cluster_name}.icp:8443/helm-repo/requiredAssets/ibm-mcm-prod-3.1.2.tgz --no-check-certificate
        tar zxvf ibm-mcm-prod-3.1.2.tgz
        kubectl create namespace mcm
        helm install --name mcm --set compliance.mcmNamespace=mcm ./ibm-mcm-prod --tls
    elif [ "${var.icp_install_mcmk}" == "true" ];then
        wget https://${var.icp_cluster_name}.icp:8443/helm-repo/requiredAssets/ibm-mcmk-prod-3.1.2.tgz --no-check-certificate
        tar zxvf ibm-mcmk-prod-3.1.2.tgz
        helm install --name mcmk --set klusterlet.apiserverConfig.server=${var.hub_cluster_url} --set klusterlet.apiserverConfig.token=${var.hub_cluster_token} --set klusterlet.clusterName=${var.icp_cluster_name} --set klusterlet.clusterNamespace=mcmk-${var.icp_cluster_name} ./ibm-mcmk-prod --tls
    fi
fi

EOF
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "bash -c 'chmod +x install_mcm.sh'",
      "bash -c './install_mcm.sh  >> install_mcm.log 2>&1'"
    ]
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