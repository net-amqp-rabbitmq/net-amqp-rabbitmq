![example workflow](https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/actions/workflows/linux-builds.yml/badge.svg)
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
make distclean; perl Makefile.PL; make

#run all tests with test debugging
NARDEBUG=1 prove -I blib/lib -I blib/arch -v t/

#run all tests in ssl mode
MQSSL=1 prove -I blib/lib -I blib/arch -v t/
```

# To build a release

```sh
perl Makefile.PL
make manifest
make dist
```

# Special note for macOS

You need `pkg-config` working, especially for openssl. There are so many different
ways to install dependencies, and so many different paths for them, it is becoming
very difficult to guess where they will be.

As a result, we're shifting to using `pkg-config` for this. Please make sure
that if you're running into any problems of missing symbols or misplaced files,
that you check this _first_.

# OpenSSL Compatibility

So far we have been testing with OpenSSL 1.1. We appear to be good there, but
OpenSSL 3 is not supported at this time.

