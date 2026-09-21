<p align="center">
  <a href="https://github.com/lupaxa-security-toolbox">
    <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/organisations/security-toolbox/readme-logo.png" alt="Security Toolbox" />
  </a>
</p>

<h1 align="center">user-notifier</h1>

PAM hooks that tell you when someone logs in or escalates privileges.
A small dispatcher then fans each event out to drop-in hooks. Slack is
the first hook.

<p align="center">
  <a href="https://user-notifier.thelupaxaproject.org/">Documentation</a>
  ·
  <a href="https://github.com/lupaxa-security-toolbox/user-notifier">GitHub</a>
</p>

## Install

From the repo root (as root, for a live machine):

```bash
sudo ./scripts/install.sh
```

The script copies the wrappers to `/usr/sbin`, the shared library to
`/usr/lib/user-notifier`, and hooks plus config to
`/etc/user-notifier`. It does not edit PAM.

Edit `/etc/user-notifier/notifier.conf` and set the Slack webhook URL
(and optionally `channel` / `username`). Defaults are channel `audit`
and username `AuditBot`.

Then add these lines (or merge them into the existing files):

```text
/etc/pam.d/su: session optional pam_exec.so seteuid /usr/sbin/escalation
/etc/pam.d/sudo: session optional pam_exec.so seteuid /usr/sbin/escalation

/etc/pam.d/login: session optional pam_exec.so /usr/sbin/connection
/etc/pam.d/sshd: session optional pam_exec.so /usr/sbin/connection
```

If you place your scripts in a different location then make sure you
update the path in the lines above.

`session optional` means a notify failure never blocks login or sudo.
Notify is synchronous; a slow webhook can delay login or sudo (it still
cannot fail the session).

## Hooks

`user-notify` runs every executable in `/etc/user-notifier/hooks.d/`
(see that directory's README). `50-slack` is installed by default.
Add another script there to also mail, syslog, or call something else.

## How it works

-   `/usr/sbin/connection` — local `login` and `sshd` sessions
-   `/usr/sbin/escalation` — `su` and `sudo`
-   Both call `/usr/sbin/user-notify`, which exports `NOTIFY_*` and runs
    the hooks

Open sessions are red in Slack; close sessions are green.

![Open session example](screenshots/example1.png)

![Close session example](screenshots/example2.png)

## Development

```bash
make init
make install-dev
make check
make mkdocs-serve
```

<a href="https://github.com/the-lupaxa-project">
    <img src="https://raw.githubusercontent.com/the-lupaxa-project/brand-assets/master/logos/components/footer-for-child-orgs.svg" alt="The Lupaxa Project Footer" width="100%" />
</a>
