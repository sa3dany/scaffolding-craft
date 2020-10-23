# -*- mode: ruby -*-
# vi: set ft=ruby :

CRAFT_HOSTNAME = ""
CRAFT_DROP_DB = "false"
CRAFT_PATH = "/vagrant/cms"

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.

  config.vm.box = "bento/ubuntu-20.04"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end

  # https://www.vagrantup.com/docs/networking
  # config.vm.network "private_network", ip: "192.168.33.10"
  # config.vm.network "public_network", ip: "10.0.0.100"

  # https://www.vagrantup.com/docs/synced-folders/basic_usage
  # Mount config and cms separately to avoid syncing **node_modules**
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder "config", "/vagrant/config"
  config.vm.synced_folder "cms", "/vagrant/cms", group: "www-data"

  # https://www.vagrantup.com/docs/provisioning/shell
  config.vm.provision "shell" do |sh|
    sh.env = {
      "CRAFT_HOSTNAME" => CRAFT_HOSTNAME,
      "CRAFT_DROP_DB" => CRAFT_DROP_DB,
      "CRAFT_PATH" => CRAFT_PATH,
    }
    sh.keep_color = true
    sh.inline = "bash /vagrant/config/provision.sh"
  end

  # https://www.vagrantup.com/docs/triggers
  # Backup db
  config.trigger.after :up do |trigger|
    trigger.warn = "Restoring database"
    trigger.run_remote = {
      env: {
        "CRAFT_PATH" => CRAFT_PATH
      },
      inline: '[ -f "/vagrant/config/mysql/dump.sql" ] && \
        "$CRAFT_PATH/craft" restore/db "/vagrant/config/mysql/dump.sql"; exit 0'
    }
  end
  # Restore db
  config.trigger.before [:halt] do |trigger|
    trigger.warn = "Dumping database"
    trigger.run_remote = {
      env: {
        "CRAFT_PATH" => CRAFT_PATH
      },
      inline: '"$CRAFT_PATH/craft" backup/db "/vagrant/config/mysql/dump.sql"'
    }
  end
end
