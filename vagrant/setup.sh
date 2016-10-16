#!/bin/bash

sudo apt-get update -qq

#add the rabbitmq repo & install
if [ ! -e /etc/apt/sources.list.d/rabbitmq.list ]; then
    echo "deb http://www.rabbitmq.com/debian/ testing main" | sudo tee /etc/apt/sources.list.d/rabbitmq.list
    curl -s https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo apt-key add -

    sudo apt-get update -o Dir::Etc::sourcelist="sources.list.d/rabbitmq.list" \
        -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

    sudo apt-get install rabbitmq-server -y

    sudo cp /vagrant/vagrant/etc/* /etc/rabbitmq/
    sudo systemctl restart rabbitmq-server

    sudo rabbitmqctl add_user admin password
    sudo rabbitmqctl set_user_tags admin administrator

    sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
    sudo rabbitmq-plugins enable rabbitmq_management
fi

#install the latest perl
which perlbrew || {
    sudo apt-get install perlbrew -y
    perlbrew init > /dev/null
    echo 'source ~/perl5/perlbrew/etc/bashrc' >> ~/.bash_profile
    source ~/perl5/perlbrew/etc/bashrc

    perlbrew install perl-stable -j2 -n --switch
    perlbrew install-cpanm

    sudo apt-get install -y libssl-dev

    bash -c 'source ~/perl5/perlbrew/etc/bashrc; cd /vagrant; cpanm --installdeps .'
}

#set the config options for the tests
test $MQSSLHOST || {
cat <<EOF >> ~/.bash_profile
export MQSSLHOST="localhost"
export MQSSLUSERNAME="guest"
export MQSSLPASSWORD="guest"
export MQHOST=\$MQSSLHOST
export MQUSERNAME=\$MQSSLUSERNAME
export MQPASSWORD=\$MQSSLPASSWORD
EOF
}
