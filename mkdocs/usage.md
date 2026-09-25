# Usage

## What the Wrappers Do

`/usr/sbin/connection` handles local `login` and `sshd` sessions.
`/usr/sbin/escalation` handles `su` and `sudo`. Both source
`/usr/lib/user-notifier/pam-common.sh`, classify the PAM environment,
and call `user-notify` with four arguments: type, hostname, details,
and state (`open` or `close`).

Same-user `sudo` to root is skipped (no notify). An empty `PAM_RUSER`
is treated as actor `unknown`.

## What `user-notify` Does

`user-notify` reads `/etc/user-notifier/notifier.conf` (or
`USER_NOTIFIER_CONFIG`), exports the hook contract, and runs every
executable in `hooks_dir` in name order. It continues after a hook
fails. Classified events always exit `0` so PAM is not failed by a
config or hook error.

Do not write to the login TTY from a hook. Use
`logger -t user-notifier` if you need logs.

## Dry-Run Without PAM

Point the wrappers at the tree in this repo and a fake notifier:

```bash
export USER_NOTIFIER_LIB="$PWD/src/pam-common.sh"
export USER_NOTIFY="$PWD/src/user-notify"
export USER_NOTIFIER_CONFIG="$PWD/config/notifier.conf.example"
export NOTIFY_TEST_HOSTNAME=testhost

PAM_TYPE=open_session PAM_SERVICE=sshd PAM_USER=user1 PAM_RHOST=10.0.0.8 \
  bash src/connection
```

`NOTIFY_TEST_HOSTNAME` overrides the live hostname so tests and
dry-runs stay deterministic.

To exercise only the dispatcher:

```bash
USER_NOTIFIER_CONFIG="$PWD/config/notifier.conf.example" \
  python3 src/user-notify ssh testhost "user1 has logged on from 10.0.0.8" open
```

With an empty webhook URL, `50-slack` is a no-op.

## Environment Overrides

| Variable               | Role                                              |
| :--------------------- | :------------------------------------------------ |
| `USER_NOTIFY`          | Path to `user-notify` (wrappers look here first)  |
| `USER_NOTIFIER_LIB`    | Path to `pam-common.sh`                           |
| `USER_NOTIFIER_CONFIG` | Path to `notifier.conf`                           |
| `NOTIFY_TEST_HOSTNAME` | Hostname used in the classified message           |

On a live install, leave these unset so `/usr/sbin` and
`/etc/user-notifier` win.
