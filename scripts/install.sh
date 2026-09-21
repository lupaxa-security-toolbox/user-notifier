#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="/usr"
DESTDIR="${DESTDIR:-}"

usage() {
    cat <<'EOF'
Usage: install.sh [--dest DIR]

Copy connection, escalation, user-notify, hooks, and example config.
Does not edit /etc/pam.d. Prints the PAM lines to add.

  --dest DIR   Prepend DIR to every destination (same as DESTDIR).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dest)
            DESTDIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

install_file() {
    local src="$1"
    local dest="$2"
    local mode="$3"
    mkdir -p "$(dirname "${dest}")"
    cp "${src}" "${dest}"
    chmod "${mode}" "${dest}"
}

sbin="${DESTDIR}${PREFIX}/sbin"
lib="${DESTDIR}${PREFIX}/lib/user-notifier"
etc="${DESTDIR}/etc/user-notifier"
hooks="${etc}/hooks.d"

install_file "${ROOT}/src/connection" "${sbin}/connection" 0755
install_file "${ROOT}/src/escalation" "${sbin}/escalation" 0755
install_file "${ROOT}/src/user-notify" "${sbin}/user-notify" 0755
install_file "${ROOT}/src/pam-common.sh" "${lib}/pam-common.sh" 0644
install_file "${ROOT}/src/hooks/50-slack" "${hooks}/50-slack" 0755
install_file "${ROOT}/src/hooks/README" "${hooks}/README" 0644
install_file "${ROOT}/config/notifier.conf.example" "${etc}/notifier.conf.example" 0644

if [[ ! -e "${etc}/notifier.conf" ]]; then
    install_file "${ROOT}/config/notifier.conf.example" "${etc}/notifier.conf" 0640
fi

cat <<'EOF'
Installed. Edit /etc/user-notifier/notifier.conf and add these PAM lines:

/etc/pam.d/su: session optional pam_exec.so seteuid /usr/sbin/escalation
/etc/pam.d/sudo: session optional pam_exec.so seteuid /usr/sbin/escalation

/etc/pam.d/login: session optional pam_exec.so /usr/sbin/connection
/etc/pam.d/sshd: session optional pam_exec.so /usr/sbin/connection

If you place the scripts in a different location then make sure you update the path in the lines above.
EOF
