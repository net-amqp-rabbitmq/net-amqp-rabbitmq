# Contributing

Your contributions are absolutely welcome!

## In order to contribute, please:

0. If you'd like to fix a problem you found, please make sure that an issue exists for it first.
1. Fork the repository on github (https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq)
2. Make your changes
3. Submit a PR to `master`.
4. Make sure your PR mentions the issue you're resolving so that we can close issues.

## When you're contributing, please observe our code quality standards (they're pretty light).

1. Do your best not to drop code coverage. There are a lot of folks who use the module, and we want to make sure everyone has a great experience.
2. Please run `make test` prior to submitting any PRs. If your tests don't pass, we can't merge your branch.
3. Please try to stick to the formatting in the file you are modifying as closely as possible.
4. Please also prove the `xt` directory, too, when you can.
5. Don't forget that we have a number of users, so check Travis-CI if you don't have access to multiple OS' for testing.

## Other requests

1. If you're looking for something to do, please consider adding test coverage or finding an issue to resolve.
2. Consider looking at the C library we use, found here: https://github.com/alanxz/rabbitmq-c
3. If you are new to C, please be careful and ask questions.
4. Please do not submit PRs which include massive formatting changes. Those are no fun to code review.

Thank you for contributing!

