[![Build Status](https://travis-ci.org/markwellis/net-amqp-rabbitmq.png)](https://travis-ci.org/markwellis/net-amqp-rabbitmq)
[![Coverage Status](https://coveralls.io/repos/markwellis/net-amqp-rabbitmq/badge.png)](https://coveralls.io/r/markwellis/net-amqp-rabbitmq)

You can install this using in the usual Perl fashion:

	perl Makefile.PL
	make
        make test
	# (or) env MQHOST="localhost" make test
	make install

If you checkout the github repo, you'll need to run the following commands
    git submodule init
    git submodule update

The documentation is in the module file.  Once you install
the file, you can read it with perldoc.

	perldoc Net::AMQP::RabbitMQ

If you want to read it before you install it, you can use
perldoc directly on the module file.

	perldoc RabbitMQ.pm
