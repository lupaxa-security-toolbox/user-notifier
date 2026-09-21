#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

FAKE="${TMP}/fake-notify"
cat > "${FAKE}" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$#" "$1" "$2" "$3" "$4" > "$(dirname "$0")/argv.txt"
EOF
chmod +x "${FAKE}"

export USER_NOTIFY="${FAKE}"
export USER_NOTIFIER_LIB="${ROOT}/src/pam-common.sh"
export NOTIFY_TEST_HOSTNAME=testhost

expect_argv() {
  local label="$1"
  shift
  local got expected
  got="$(cat "${TMP}/argv.txt")"
  expected="$(printf '%s\n' "$@")"
  [[ "${got}" == "${expected}" ]] || {
    echo "FAIL ${label} argv:" >&2
    echo "  got:      ${got//$'\n'/ | }" >&2
    echo "  expected: ${expected//$'\n'/ | }" >&2
    exit 1
  }
}

PAM_TYPE=open_session PAM_SERVICE=sshd PAM_USER=wolf PAM_RHOST=10.0.0.1 \
  bash "${ROOT}/src/connection"
expect_argv connection 4 ssh testhost 'wolf has logged on from 10.0.0.1' open

rm -f "${TMP}/argv.txt"
PAM_TYPE=open_session PAM_SERVICE=sudo PAM_USER=root PAM_RUSER=wolf PAM_TTY=/dev/pts/0 \
  bash "${ROOT}/src/escalation"
expect_argv escalation 4 sudo testhost 'wolf is impersonating root on /dev/pts/0' open

rm -f "${TMP}/argv.txt"
PAM_TYPE=open_session PAM_SERVICE=sudo PAM_USER=root PAM_RUSER=root PAM_TTY=/dev/pts/0 \
  bash "${ROOT}/src/escalation"
if [[ -f "${TMP}/argv.txt" ]]; then
  echo "FAIL same-user should not call notifier" >&2
  exit 1
fi

echo "All wrapper tests passed."
