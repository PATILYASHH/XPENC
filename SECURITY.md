# Security Policy

XPENC is a money app that keeps all financial data on-device. Security and
privacy are the whole trust story, so reports are taken seriously.

## Supported versions

Only the [latest release](https://github.com/PATILYASHH/XPENC/releases/latest)
receives security fixes.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Use GitHub's private vulnerability reporting instead:

1. Go to the repository's **Security** tab
2. Click **Report a vulnerability**
3. Describe the issue, steps to reproduce, and impact

You should receive a response within a few days. Once fixed, the report will be
credited (unless you prefer otherwise) in the release notes.

## Scope notes

- XPENC has **no server** — there is no backend, API, or cloud component to test.
- In scope: anything that leaks transaction/balance data off the device,
  corrupts the ledger, or bypasses the on-device-only guarantee. (Since 1.1.0
  the app requests no SMS permission at all — see [PRIVACY.md](PRIVACY.md).)
- The APKs published on GitHub Releases are the only official builds. Verify
  downloads against `SHA256SUMS.txt` attached to each release.
