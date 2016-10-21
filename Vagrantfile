VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "bento/debian-8.5"

    config.vm.hostname = "nardev"
    config.vm.provider "virtualbox" do |v|
        v.memory = 512
        v.linked_clone = true if Vagrant::VERSION =~ /^1.8/
    end

    config.vm.provision "shell",
        path: "vagrant/setup.sh",
        privileged: false
end
