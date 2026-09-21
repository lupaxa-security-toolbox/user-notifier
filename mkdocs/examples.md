# Examples

The contract (env, argv, skip rules) lives in
[Reference](reference.md) and in `hooks.d/README`. These are extra
recipes. Save each file in `/etc/user-notifier/hooks.d/`, then
`chmod +x`.

## Syslog

```bash
#!/bin/sh
logger -t user-notifier -- "${NOTIFY_TYPE} ${NOTIFY_STATE} ${NOTIFY_HOST} ${NOTIFY_DETAILS}"
```

Save as `40-syslog`.

## Mail root

```bash
#!/bin/sh
printf '%s\n' "${NOTIFY_DETAILS}" \
  | mail -s "user-notifier ${NOTIFY_TYPE} ${NOTIFY_STATE} on ${NOTIFY_HOST}" root
```

Save as `60-mail`. Needs a working local `mail` command.

## Sudo only

Skip everything except privilege escalation:

```bash
#!/bin/sh
case "${NOTIFY_TYPE}" in
  sudo|su) ;;
  *) exit 0 ;;
esac
logger -t user-notifier -- "${NOTIFY_TYPE} ${NOTIFY_STATE} ${NOTIFY_DETAILS}"
```

Save as `30-sudo-only`.

## Second webhook

`50-slack` reads `SLACK_WEBHOOK_URL`. For another channel, hard-code a
second URL in its own hook (keep the secret in a `0640` file, not in
git):

```bash
#!/usr/bin/env python3
import json
import os
import urllib.request

url = open("/etc/user-notifier/ops.webhook", encoding="utf-8").read().strip()
if not url:
    raise SystemExit(0)
payload = {
    "channel": "#ops",
    "username": "AuditBot",
    "text": f"{os.environ.get('NOTIFY_TYPE')} {os.environ.get('NOTIFY_DETAILS')}",
}
req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
urllib.request.urlopen(req, timeout=15)
```

Save as `55-ops-slack`.

## Dry-run one hook

```bash
NOTIFY_TYPE=ssh \
NOTIFY_HOST=testhost \
NOTIFY_DETAILS="user1 has logged on from 10.0.0.8" \
NOTIFY_STATE=open \
NOTIFY_COLOR=danger \
  /etc/user-notifier/hooks.d/40-syslog
```
