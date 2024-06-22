![example workflow](https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/actions/workflows/linux-builds.yml/badge.svg)
[![Coverage Status](https://coveralls.io/repos/net-amqp-rabbitmq/net-amqp-rabbitmq/badge.png)](https://coveralls.io/r/net-amqp-rabbitmq/net-amqp-rabbitmq)

# NOTICE

This module is presently in a difficult-to-maintain state, and caution should be used in using it.

- The OpenSSL version used by the `librabbitmq-c` library is end-of-life
- The code duplication in this module makes it very difficult to keep up with C library updates

There is a [GitHub Discussion here regarding paths forward](https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/discussions/241), and if you use this module then your input is requested.

It is important that if you use this module, that you mitigate these risks to your satisfaction, or to that of your organization.

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

When running your own tests, for quick access to a testing RabbitMQ service, consider [CloudAMQP](https://cloudamqp.com).

There are a few convenience scripts to help you out:

- `local-tests-no-ssl` - Convenience script to run tests on a local network without SSL at all.
- `run-one-test` - This script helps you quickly run a single test while working on this project.
- `ci/run-ci-tests.sh` - This script is what we run in GitHub Actions, it'll help you run the full suite.

# To build a release

```sh
make distclean
perl Makefile.PL
make manifest
make dist
```

## Known challenges

- In order to run test `024_boolean_header_fields.t`, you need to have the web client for RabbitMQ enabled, and your test user must have access to it. This is because this test uses the web client to test specific use cases which require a literal Boolean type (which Perl lacks).

# Special note for macOS

You need `pkg-config` working, especially for openssl. There are so many different
ways to install dependencies, and so many different paths for them, it is becoming
very difficult to guess where they will be.

As a result, we're shifting to using `pkg-config` for this. Please make sure
that if you're running into any problems of missing symbols or misplaced files,
that you check this _first_.

# OpenSSL Compatibility

To date, OpenSSL v3 is supported.
