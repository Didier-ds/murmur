# Security Policy

Murmur has access to your microphone and, through the Accessibility permission, to other apps' text fields and to keyboard events while you dictate. Security reports are taken seriously.

## Reporting a vulnerability

Please **don't open a public issue** for security problems.

Report privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability**. Include:

- what an attacker could do, and under which conditions
- steps to reproduce, and the macOS version and app you were dictating into
- the Murmur version (menu bar ring → right-click)

You'll get an acknowledgement within a few days. Once a fix is released, the report is credited in the release notes unless you'd rather stay anonymous.

## Supported versions

Only the latest release gets security fixes.

## Scope

In scope: anything in the Murmur app, for example keystrokes or dictated text leaking, text being inserted somewhere other than where the user started, the microphone staying on after dictation ends, or ways to get Murmur to run code.

Out of scope: the `promo/` video project (local development tooling that doesn't ship), and issues in macOS itself, which should go to Apple.
