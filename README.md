[![Build Status](https://travis-ci.org/net-amqp-rabbitmq/net-amqp-rabbitmq.png)](https://travis-ci.org/net-amqp-rabbitmq/net-amqp-rabbitmq)
[![Coverage Status](https://coveralls.io/repos/net-amqp-rabbitmq/net-amqp-rabbitmq/badge.png)](https://coveralls.io/r/net-amqp-rabbitmq/net-amqp-rabbitmq)

# Install

` cpanm Net::AMQP::RabbitMQ`

or

`cpan Net::AMQP::RabbitMQ`

# Documentation

<https://metacpan.org/pod/Net::AMQP::RabbitMQ>

or once installed `perldoc Net::AMQP::RabbitMQ`

# Tests

There are several environment variables you can set that influence the tests.

<https://metacpan.org/pod/Net::AMQP::RabbitMQ#RUNNING-THE-TEST-SUITE>

# For developers/authors

Once you have cloned the repo, you will need to download the submodules.

```sh
git submodule init
git submodule update
```

There is a vagrant development environment available, with a local rabbitmq installation and ssl enabled.

The test environment variables have been set to use this install


```sh
vagrant up
vagrant ssh
cd /vagrant
cpanm Module::CAPIMaker
make distclean; perl Makefile.PL; make

#run all tests with test debugging
NARDEBUG=1 prove -I blib/lib -I blib/arch -v t/

#run all tests in ssl mode
MQSSL=1 prove -I blib/lib -I blib/arch -v t/
```
