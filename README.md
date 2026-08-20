# Server Toolkit

Server Toolkit is a read-only VPS audit tool for Ubuntu and Debian.

## Status

This repository currently contains a **1.0.0 test candidate** for manual E2E
validation. It is not a stable release and no `latest` installation channel is
provided.

The public interface includes:

- interactive menu;
- full read-only audit;
- limited quick check;
- newest verified local report;
- integrity verification and uninstall.

The public edition does not perform package updates, remediation, firewall or
SSH changes, report upload, telemetry, fleet management, or automatic audit
after installation.

## Test distribution

The exact publication assets are under:

`release/public-menu-v2/public/`

Use only a commit-pinned command with the documented size and SHA-256 checks.
Do not install from a branch name, tag, redirect, or unverified
`curl | bash` command.

Reports remain on the audited server with protected local permissions. This
test candidate has not yet completed the owner-approved live E2E gate.
