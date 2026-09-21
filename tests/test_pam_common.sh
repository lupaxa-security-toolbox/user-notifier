#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Dynamic ROOT path; pam-common.sh is the only source.
# shellcheck disable=SC1091
source "${ROOT}/src/pam-common.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok: $*"; }

export NOTIFY_TEST_HOSTNAME=testhost

# PAM_* are inputs to the sourced classifiers (same as pam_exec.so).
set_pam() {
  export MSG=""
  export STATE=""
  export PAM_TYPE="${1-}"
  export PAM_SERVICE="${2-}"
  export PAM_USER="${3-}"
  export PAM_RUSER="${4-}"
  export PAM_TTY="${5-}"
  export PAM_RHOST="${6-}"
}

set_pam open_session login wolf "" /dev/tty1
classify_connection
[[ "${STATE}" == "open" ]] || fail "login open state"
[[ "${MSG}" == "local login,testhost,wolf logged onto /dev/tty1" ]] || fail "login open msg: ${MSG}"
pass "login open"

set_pam close_session login wolf "" /dev/tty1
classify_connection
[[ "${STATE}" == "close" ]] || fail "login close state"
[[ "${MSG}" == "local login,testhost,wolf logged off /dev/tty1" ]] || fail "login close msg: ${MSG}"
pass "login close"

set_pam open_session sshd wolf "" "" 10.0.0.8
classify_connection
[[ "${MSG}" == "ssh,testhost,wolf has logged on from 10.0.0.8" ]] || fail "ssh open: ${MSG}"
pass "ssh open"

set_pam close_session sshd wolf "" "" 10.0.0.8
classify_connection
[[ "${MSG}" == "ssh,testhost,wolf logged off from 10.0.0.8" ]] || fail "ssh close: ${MSG}"
pass "ssh close"

set_pam open_session gdm wolf wolf /dev/tty2 1.2.3.4
classify_connection
[[ "${MSG}" == "Abnormality,testhost,wolf logged on /dev/tty2 from 1.2.3.4 using gdm and wolf" ]] || fail "conn abn: ${MSG}"
pass "connection abnormality service"

set_pam acct sshd wolf wolf ssh 10.0.0.8
classify_connection
[[ "${STATE}" == "open" ]] || fail "unhandled type state"
[[ "${MSG}" == "Abnormality,testhost,Unhandled call to the logger. Data=10.0.0.8, wolf, sshd, ssh, wolf and acct" ]] || fail "unhandled: ${MSG}"
pass "unhandled PAM_TYPE spacing"

set_pam open_session sudo root wolf /dev/pts/0
classify_escalation
[[ "${STATE}" == "open" ]] || fail "sudo open state"
[[ "${MSG}" == "sudo,testhost,wolf is impersonating root on /dev/pts/0" ]] || fail "sudo open: ${MSG}"
pass "sudo to root"

set_pam close_session sudo root wolf /dev/pts/0
classify_escalation
[[ "${MSG}" == "sudo,testhost,wolf is no longer impersonating root on /dev/pts/0" ]] || fail "sudo close: ${MSG}"
pass "sudo close"

set_pam open_session sudo backup wolf /dev/pts/1
classify_escalation
[[ "${MSG}" == "sudo,testhost,wolf is impersonating backup on /dev/pts/1" ]] || fail "sudo other: ${MSG}"
pass "sudo to other user"

set_pam open_session sudo root root /dev/pts/0
classify_escalation
[[ -z "${MSG}" ]] || fail "same-user root should skip: ${MSG}"
pass "same-user sudo root skip"

set_pam open_session sudo root "" /dev/pts/0
unset SUDO_USER
classify_escalation
[[ "${MSG}" == "sudo,testhost,unknown is impersonating root on /dev/pts/0" ]] \
  || fail "empty RUSER: ${MSG}"
pass "empty PAM_RUSER uses unknown actor"

set_pam open_session su root wolf /dev/pts/2
classify_escalation
[[ "${MSG}" == "su,testhost,wolf is impersonating root on /dev/pts/2" ]] || fail "su open: ${MSG}"
pass "su to root"

set_pam close_session su nobody wolf /dev/pts/2
classify_escalation
[[ "${MSG}" == "su,testhost,wolf is no longer impersonating nobody on /dev/pts/2" ]] || fail "su close other: ${MSG}"
pass "su close other"

set_pam open_session polkit root wolf /dev/pts/3 ""
classify_escalation
[[ "${MSG}" == "Abnormality,testhost,Unhandled impersonification between wolf and root on /dev/pts/3 (using service polkit and host )" ]] || fail "esc abn: ${MSG}"
pass "escalation abnormality service"

export USER_NOTIFY="${ROOT}/src/user-notify"
found="$(find_notifier)" || fail "find_notifier with USER_NOTIFY"
[[ "${found}" == "${USER_NOTIFY}" ]] || fail "find_notifier path: ${found}"
pass "find_notifier callable"

echo "All pam-common tests passed."
