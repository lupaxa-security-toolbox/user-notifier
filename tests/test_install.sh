#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$(mktemp -d)"
trap 'rm -rf "${DEST}"' EXIT

out="$(bash "${ROOT}/scripts/install.sh" --dest "${DEST}")"

need=(
  "${DEST}/usr/sbin/connection"
  "${DEST}/usr/sbin/escalation"
  "${DEST}/usr/sbin/user-notify"
  "${DEST}/usr/lib/user-notifier/pam-common.sh"
  "${DEST}/etc/user-notifier/hooks.d/50-slack"
  "${DEST}/etc/user-notifier/hooks.d/README"
  "${DEST}/etc/user-notifier/notifier.conf.example"
  "${DEST}/etc/user-notifier/notifier.conf"
)
for path in "${need[@]}"; do
  [[ -e "${path}" ]] || { echo "FAIL missing ${path}" >&2; exit 1; }
done
[[ -x "${DEST}/usr/sbin/connection" ]] || { echo "FAIL connection not executable" >&2; exit 1; }
[[ -x "${DEST}/usr/sbin/user-notify" ]] || { echo "FAIL user-notify not executable" >&2; exit 1; }
[[ -x "${DEST}/etc/user-notifier/hooks.d/50-slack" ]] || { echo "FAIL 50-slack not executable" >&2; exit 1; }

file_mode() {
  local path="$1"
  if stat -f %Lp "${path}" >/dev/null 2>&1; then
    stat -f %Lp "${path}"
  elif stat -c %a "${path}" >/dev/null 2>&1; then
    stat -c %a "${path}"
  else
    echo "FAIL cannot stat mode for ${path}" >&2
    exit 1
  fi
}

conf_mode="$(file_mode "${DEST}/etc/user-notifier/notifier.conf")"
[[ "${conf_mode}" == "640" ]] || {
  echo "FAIL notifier.conf mode ${conf_mode}, want 640" >&2
  exit 1
}
example_mode="$(file_mode "${DEST}/etc/user-notifier/notifier.conf.example")"
[[ "${example_mode}" == "644" ]] || {
  echo "FAIL notifier.conf.example mode ${example_mode}, want 644" >&2
  exit 1
}

echo 'webhook_url = keep-me' > "${DEST}/etc/user-notifier/notifier.conf"
bash "${ROOT}/scripts/install.sh" --dest "${DEST}" >/dev/null
grep -q 'keep-me' "${DEST}/etc/user-notifier/notifier.conf" || {
  echo "FAIL overwritten live config" >&2
  exit 1
}

printf '%s\n' "${out}" | grep -F '/etc/pam.d/su: session optional pam_exec.so seteuid /usr/sbin/escalation' >/dev/null
printf '%s\n' "${out}" | grep -F '/etc/pam.d/sudo: session optional pam_exec.so seteuid /usr/sbin/escalation' >/dev/null
printf '%s\n' "${out}" | grep -F '/etc/pam.d/login: session optional pam_exec.so /usr/sbin/connection' >/dev/null
printf '%s\n' "${out}" | grep -F '/etc/pam.d/sshd: session optional pam_exec.so /usr/sbin/connection' >/dev/null

README="${ROOT}/README.md"
grep -F '/etc/pam.d/su: session optional pam_exec.so seteuid /usr/sbin/escalation' "${README}" >/dev/null
grep -F '/etc/pam.d/sshd: session optional pam_exec.so /usr/sbin/connection' "${README}" >/dev/null
grep -q 'scripts/install.sh' "${README}" || { echo "FAIL README missing install.sh" >&2; exit 1; }
grep -q '/etc/user-notifier/notifier.conf' "${README}" || { echo "FAIL README missing config path" >&2; exit 1; }
grep -q 'hooks.d' "${README}" || { echo "FAIL README missing hooks.d" >&2; exit 1; }
if grep -qiE 'AntiPhotonltd|travis-ci.org/AntiPhotonltd' "${README}"; then
  echo "FAIL stale slack-audit badges still in README" >&2
  exit 1
fi
if grep -qiE '^## Licence|^## License|^## Project layout|^## Community' "${README}"; then
  echo "FAIL README grew a forbidden section" >&2
  exit 1
fi
if [[ -e "${ROOT}/src/slack-notifier" ]]; then
  echo "FAIL Perl slack-notifier should be removed" >&2
  exit 1
fi

echo "All install tests passed."
