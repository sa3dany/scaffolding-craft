# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.

  config.vm.box = "bento/ubuntu-20.04"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port",
  #  guest: 80, host: 80, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network "public_network", ip: "${SCAFFOLDING_VAGRANT_IP}"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"
  # For smb use:
  # config.vm.synced_folder "../data", "/vagrant_data", type: "smb",
  #   mount_options: ["dir_mode=0775,file_mode=0774"]
  config.vm.synced_folder ".", "/vagrant",  disabled: true
  config.vm.synced_folder "config", "/vagrant/config"
  config.vm.synced_folder "cms", "/vagrant/cms", group: "www-data"

  config.vm.provider "virtualbox" do |vb|
    # vb.gui = true
    vb.memory = "4096"
    vb.name = "${SCAFFOLDING_PROJECT_NAME}"
  end

  config.vm.provision "shell", path: "config/provision.sh", args: [
    "--config-path=/vagrant/config",
    "--craft-path=/vagrant/cms",
    "--php=7.4"
  ]
end
