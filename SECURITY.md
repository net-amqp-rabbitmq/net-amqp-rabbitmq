# Security Policy

## Supported Versions

While I do retain older versions in CPAN for purposes of not impacting users who depend on them, please reference the table below for supported versions. Any version falling behind the support window should be understood to be end-of-life and unsupported. **This project does not backport security patches to older versions.**

| Version    | Supported          |
| ---------- | ------------------ |
| >= 2.40011 | :white_check_mark: |
| < 2.40011  | :x:                |

> [!IMPORTANT]
> Versions prior to `2.40011` may use OpenSSL 1.x versions which are end-of-life and known to have high-severity CVEs.

## Reporting a Vulnerability

To report a vulnerability, please use the [Security Tab on GitHub](https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/security), and click the ["Report a vulnerability" button](https://github.com/net-amqp-rabbitmq/net-amqp-rabbitmq/security/advisories/new).

- Security vulnerabilities will be triaged as soon as possible
- Once a vulnerability has been mitigated, the vulnerability will be disclosed in its entirety, beginning with the original report
- If a report turns out to not be a problem, the report will still be made public
- Obvious spam reports will also be made public, but will be made public with appropriate amounts of snark added for flavor

> [!IMPORTANT]
> If you would like your identity to remain confidential, **YOU MUST SAY SO IN YOUR REPORT CONSPICUOUSLY!** I will keep confidence, but only if I understand that it is confidential.
