# Reference

The hook contract also ships on the box as
`/etc/user-notifier/hooks.d/README` (from `src/hooks/README`). Treat
that file as the interface. This page is the same contract, plus
paths and config keys.

## Hook naming

Drop an executable in `hooks_dir`. `user-notify` runs every hook in
name order and continues if one fails.

Use `NN-name` so order is obvious. `50-slack` is the first-party Slack
webhook hook.

Skipped names: `README*`, `*.example`, anything starting with `.`.

## Environment

| Variable            | Meaning                                                  |
| :------------------ | :------------------------------------------------------- |
| `NOTIFY_TYPE`       | `ssh`, `sudo`, `su`, `local login`, `Abnormality`, …     |
| `NOTIFY_HOST`       | hostname                                                 |
| `NOTIFY_DETAILS`    | human sentence                                           |
| `NOTIFY_STATE`      | `open` or `close`                                        |
| `NOTIFY_COLOR`      | `danger` (open) or `good` (close)                        |
| `SLACK_WEBHOOK_URL` | from `/etc/user-notifier/notifier.conf`                  |
| `SLACK_CHANNEL`     | from config (default `audit`)                            |
| `SLACK_USERNAME`    | from config (default `AuditBot`)                         |
| `NOTIFY_HOOKS_DIR`  | this directory                                           |

Argv is the same four fields: `type` `host` `details` `state`.

Exit non-zero to signal failure. Other hooks still run. Do not write
to the login TTY; use `logger -t user-notifier` if you need logs.

## Config

`/etc/user-notifier/notifier.conf` (INI):

```ini
[notify]
hooks_dir = /etc/user-notifier/hooks.d

[slack]
webhook_url =
channel = audit
username = AuditBot
```

`hooks_dir` is shared. Slack keys are only required for `50-slack`.
The installer writes a live `notifier.conf` at mode `0640` and will
not overwrite an existing live file.

## Install paths

| Path                                         | What                                             |
| :------------------------------------------- | :----------------------------------------------- |
| `/usr/sbin/connection`                       | `login` / `sshd` wrapper                         |
| `/usr/sbin/escalation`                       | `su` / `sudo` wrapper                            |
| `/usr/sbin/user-notify`                      | dispatcher                                       |
| `/usr/lib/user-notifier/pam-common.sh`       | shared classifiers                               |
| `/etc/user-notifier/notifier.conf`           | live config                                      |
| `/etc/user-notifier/notifier.conf.example`   | example copy                                     |
| `/etc/user-notifier/hooks.d/`                | drop-in hooks                                    |
| `/etc/user-notifier/hooks.d/50-slack`        | Slack webhook                                    |
| `/etc/user-notifier/hooks.d/README`          | hook contract                                    |

## Dispatcher exit codes

| Code | When                                                                  |
| :--- | :-------------------------------------------------------------------- |
| `0`  | Classified event dispatched (hook failures included)                  |
| `1`  | Usage: called without the four PAM-derived arguments and no PAM env   |
