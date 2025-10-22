# Contributing

Your contributions are absolutely welcome!

## Reporting issues:

Hey all, it's just me maintaining this module. I'm a busy person, and my time working on this module is prescious and short. If you would like to submit an issue, please observe the following:

0. I'm going to try my best to resolve your issues, but if I can't figure out how to test or replicate the issue you report, I won't be able to help you.
1. If you are reporting a bug that you found, _please_ attach a simple test program to your bug. This will help me see what you're saying much more quickly, and it'll help me fix your issue more quickly.
2. I mostly develop on macOS, so if you have an issue that you suspect is OS-specific, please attach a `Dockerfile` (or equivalent) so that I can check the issue out inside that environment.
3. If you have an SSL-specific issue, please verify that it also occurs on the default test install, or help me figure out how to test it otherwise.

## In order to contribute, please:

0. If you'd like to fix a problem you found, please make sure that an issue exists for it first.
1. Fork the repository on github (https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq)
2. Make your changes
3. Submit a PR to `main`.
4. Make sure your PR mentions the issue you're resolving so that we can close issues.

## When you're contributing, please observe our code quality standards (they're pretty light).

1. Do your best not to drop code coverage. There are a lot of folks who use the module, and we want to make sure everyone has a great experience.
2. Please run `ci/run-ci-tests.sh` prior to submitting any PRs. If your tests don't pass, we can't merge your branch.
3. Please try to stick to the formatting in the file you are modifying as closely as possible.
4. Please also prove the `xt` directory, too, when you can.
5. Don't forget that we have a number of users, so check the GitHub Actions if you don't have access to multiple OS' for testing.
6. Please make sure that your contribution _also_ works on a CloudAMQP test host.

## Other requests

1. If you're looking for something to do, please consider adding test coverage or finding an issue to resolve.
2. Consider looking at the C library we use, found here: https://github.com/alanxz/rabbitmq-c
3. If you are new to C, please be careful and ask questions.
4. Please do not submit PRs which include massive formatting changes. Those are no fun to code review.

Thank you for contributing!

