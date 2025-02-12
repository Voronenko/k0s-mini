require_relative 'deployment/vagrant/lib/vagrant'
require 'pp'

# Absolute paths on the host machine.
host_vm_dir = File.dirname(File.expand_path(__FILE__))
host_project_dir = ENV['VM_PROJECT_ROOT'] || host_vm_dir
host_config_dir = ENV['VM_CONFIG_DIR'] ? "#{host_project_dir}/#{ENV['VM_CONFIG_DIR']}" : host_project_dir

# Absolute paths on the guest machine.
guest_project_dir = '/vagrant'
guest_vm_dir = ENV['VM_DIR'] ? "/vagrant/#{ENV['VM_DIR']}" : guest_project_dir
guest_config_dir = ENV['VM_CONFIG_DIR'] ? "/vagrant/#{ENV['VM_CONFIG_DIR']}" : guest_project_dir

vm_env = ENV['VM_ENV'] || 'vagrant'

default_config_file = "#{host_vm_dir}/deployment/vagrant/vagrant_config.yml"
unless File.exist?(default_config_file)
  raise_message "Configuration file not found! Expected in #{default_config_file}"
end

vconfig = load_config([
  default_config_file,
  "#{host_config_dir}/config.yml",
  "#{host_config_dir}/#{vm_env}.config.yml",
  "#{host_config_dir}/local.config.yml"
])

ensure_plugins(vconfig['vagrant_plugins'])

vagrant_machines = Hash.new

Vagrant.configure("2") do |config|
#    vagrant plugin install vagrant-disksize
  config.vbguest.auto_update = vconfig['plugin_vbguest_auto_update'] if Vagrant.has_plugin?('vagrant-vbguest')
  config.disksize.size = '100GB'
  config.vm.boot_timeout = 600

  vconfig['vagrant_machines'].each do |machine|
    config.vm.define machine['vagrant_machine_name'] do |vm_config|
      # Networking configuration.
      vm_config.vm.hostname = machine['vagrant_hostname']
      vm_config.vm.network :private_network,
        ip: machine['vagrant_ip'],
        auto_network: machine['vagrant_ip'] == '0.0.0.0' && Vagrant.has_plugin?('vagrant-auto_network')

      unless machine['vagrant_public_ip'].nil? || machine['vagrant_public_ip'].empty?
        vm_config.vm.network :public_network,
          ip: machine['vagrant_public_ip'] != '0.0.0.0' ? machine['vagrant_public_ip'] : nil,
          bridge: ["enp172s0"]
      end

      unless machine['vagrant_internal_ip'].nil? || machine['vagrant_internal_ip'].empty?
        vm_config.vm.network :private_network,
          ip: machine['vagrant_internal_ip'] != '0.0.0.0' ? machine['vagrant_internal_ip'] : nil,
          virtualbox__intnet: "intnet1",
          netmask: "255.255.0.0",
          hostsupdater: "skip"
      end
      # DIRTY - FIND PROPER WAY TO REMOVE ADAPTER LEFT FROM ORIGINAL IMAGE WITH SYNTAX ABOVE
      unless machine['vagrant_internal_ip'].nil? || machine['vagrant_internal_ip'].empty?
          vm_config.vm.provision "shell", inline: <<-SHELL
            # Bring up the specified interface with IP configuration
           sudo rm /etc/netplan/50-cloud-init.yaml
          SHELL
      end

      # SSH options.
      vm_config.ssh.insert_key = true
      vm_config.ssh.forward_agent = true

      # Vagrant box.
      vm_config.vm.box = vconfig['vagrant_box']

      # Display an introduction message after `vagrant up` and `vagrant provision`.
      vm_config.vm.post_up_message = vconfig.fetch('vagrant_post_up_message', get_default_post_up_message(vconfig))

      # If a hostsfile manager plugin is installed, add all server names as aliases.
      aliases = get_vhost_aliases(vconfig) - [vm_config.vm.hostname]
      if Vagrant.has_plugin?('vagrant-hostsupdater')
        vm_config.hostsupdater.aliases = aliases
      elsif Vagrant.has_plugin?('vagrant-hostmanager')
        vm_config.hostmanager.enabled = true
        vm_config.hostmanager.manage_host = true
        vm_config.hostmanager.aliases = aliases
      end

      # Sync the project root directory to /vagrant
      unless vconfig['vagrant_synced_folders'].any? { |synced_folder| synced_folder['destination'] == '/vagrant' }
        vconfig['vagrant_synced_folders'].push(
          'local_path' => host_project_dir,
          'destination' => '/vagrant'
        )
      end

      # Synced folders.
      vconfig['vagrant_synced_folders'].each do |synced_folder|
        options = {
          type: synced_folder.fetch('type', vconfig['vagrant_synced_folder_default_type']),
          rsync__exclude: synced_folder['excluded_paths'],
          rsync__args: ['--verbose', '--archive', '--delete', '-z', '--copy-links', '--chmod=ugo=rwX'],
          id: synced_folder['id'],
          create: synced_folder.fetch('create', false),
          mount_options: synced_folder.fetch('mount_options', []),
          nfs_udp: synced_folder.fetch('nfs_udp', false)
        }
        synced_folder.fetch('options_override', {}).each do |key, value|
          options[key.to_sym] = value
        end
        vm_config.vm.synced_folder synced_folder.fetch('local_path'), synced_folder.fetch('destination'), options
      end

      # VMware Fusion.
      vm_config.vm.provider :vmware_fusion do |v, override|
        # HGFS kernel module currently doesn't load correctly for native shares.
        override.vm.synced_folder host_project_dir, '/vagrant', type: 'nfs'

        v.gui = vconfig['vagrant_gui']
        v.vmx['memsize'] = vconfig['vagrant_memory']
        v.vmx['numvcpus'] = vconfig['vagrant_cpus']
      end

      # VirtualBox.
      vm_config.vm.provider :virtualbox do |v|
        v.linked_clone = true
        v.name = machine['vagrant_hostname']
        v.memory = machine.fetch('vagrant_memory', vconfig['vagrant_memory'])
        v.cpus = machine.fetch('vagrant_cpus', vconfig['vagrant_cpus'])
        v.customize ['modifyvm', :id, '--uartmode1', 'disconnected']
        v.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
        v.customize ['modifyvm', :id, '--ioapic', 'on']
        v.customize ['modifyvm', :id, '--audio', 'none']
        v.gui = vconfig['vagrant_gui']
      end

      # Parallels.
      vm_config.vm.provider :parallels do |p, override|
        override.vm.box = vconfig['vagrant_box']
        p.name = machine['vagrant_hostname']
        p.memory = vconfig['vagrant_memory']
        p.cpus = vconfig['vagrant_cpus']
        p.update_guest_tools = true
      end

      # Cache packages and dependencies if vagrant-cachier plugin is present.
      if Vagrant.has_plugin?('vagrant-cachier')
        vm_config.cache.scope = :box
        vm_config.cache.auto_detect = false
        vm_config.cache.enable :apt
        vm_config.cache.enable :generic, cache_dir: '/home/vagrant/.composer/cache'
        vm_config.cache.synced_folder_opts = {
          type: vconfig['vagrant_synced_folder_default_type'],
          nfs_udp: false
        }
      end

      vagrant_machines[machine['vagrant_machine_name'] ] = vm_config.dup

      vm_config.vm.provision "shell" do |s|
        # Put below your favorite public key, kind of id_ed25519.pub, id_rsa.pub
        ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_ed25519.pub").first.strip
        s.inline = <<-SHELL
          echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
          echo #{ssh_pub_key} >> /root/.ssh/authorized_keys
        SHELL
      end
    end
  end

  # Allow an untracked Vagrantfile to modify the configurations
  [host_config_dir, host_project_dir].uniq.each do |dir|
    eval File.read "#{dir}/Vagrantfile.local" if File.exist?("#{dir}/Vagrantfile.local")
  end

end
