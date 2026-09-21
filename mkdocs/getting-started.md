# Getting started

## Requirements

-   Linux with PAM (`pam_exec.so`)
-   Python 3.10 or newer on the host (the dispatcher and Slack hook use
    the standard library only)
-   Root on the machine you are wiring up
-   A Slack incoming webhook URL if you want the default hook

## Install

From the repo root, as root, on the live machine:

```bash
sudo ./scripts/install.sh
```

The script copies the wrappers to `/usr/sbin`, the shared library to
`/usr/lib/user-notifier`, and hooks plus config to
`/etc/user-notifier`. It does **not** edit PAM.

Edit `/etc/user-notifier/notifier.conf` and set the Slack webhook URL
(and optionally `channel` / `username`). Defaults are channel `audit`
and username `AuditBot`. The live file is mode `0640`.

Then add these lines (or merge them into the existing files):

```text
/etc/pam.d/su: session optional pam_exec.so seteuid /usr/sbin/escalation
/etc/pam.d/sudo: session optional pam_exec.so seteuid /usr/sbin/escalation

/etc/pam.d/login: session optional pam_exec.so /usr/sbin/connection
/etc/pam.d/sshd: session optional pam_exec.so /usr/sbin/connection
```

If you place the scripts in a different location, update the paths in
those lines.

`session optional` means a notify failure never blocks login or sudo.
Notify is synchronous; a slow webhook can delay login or sudo (it still
cannot fail the session).

## First event

After PAM is wired, open an SSH session or run `sudo -s`. You should
see a Slack message with Type, Hostname, and Details. Closing the
session sends a green follow-up.

To confirm the files landed without touching PAM:

```bash
ls -l /usr/sbin/connection /usr/sbin/escalation /usr/sbin/user-notify
ls -l /etc/user-notifier/hooks.d /etc/user-notifier/notifier.conf
```

## Development checkout

On a workstation you can install makefile-skills and run the suite
without becoming root:

```bash
make init
make install-dev
make check
make mkdocs-serve
```

See [Usage](usage.md) for a PAM-free dry-run.
