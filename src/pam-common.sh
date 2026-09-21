#!/usr/bin/env bash
# Shared PAM classifiers for connection and escalation wrappers.
# Safe to source. Does not set -e (PAM wrappers must always exit 0).

log_notifier() {
    if command -v logger >/dev/null 2>&1; then
        logger -t user-notifier -- "$*"
    fi
}

_notifier_hostname() {
    if [[ -n "${NOTIFY_TEST_HOSTNAME:-}" ]]; then
        printf '%s\n' "${NOTIFY_TEST_HOSTNAME}"
    else
        hostname
    fi
}

find_notifier() {
    if [[ -n "${USER_NOTIFY:-}" && -x "${USER_NOTIFY}" ]]; then
        printf '%s\n' "${USER_NOTIFY}"
        return 0
    fi
    if [[ -x /usr/sbin/user-notify ]]; then
        printf '%s\n' /usr/sbin/user-notify
        return 0
    fi
    if command -v user-notify >/dev/null 2>&1; then
        command -v user-notify
        return 0
    fi
    return 1
}

classify_connection() {
    local hostname
    hostname="$(_notifier_hostname)"
    MSG=""
    STATE=""
    case "${PAM_TYPE:-}" in
        open_session)
            STATE=open
            case "${PAM_SERVICE:-}" in
                login)
                    MSG="local login,${hostname},${PAM_USER} logged onto ${PAM_TTY}"
                    ;;
                sshd)
                    MSG="ssh,${hostname},${PAM_USER} has logged on from ${PAM_RHOST}"
                    ;;
                *)
                    MSG="Abnormality,${hostname},${PAM_USER} logged on ${PAM_TTY} from ${PAM_RHOST} using ${PAM_SERVICE} and ${PAM_RUSER}"
                    ;;
            esac
            ;;
        close_session)
            STATE=close
            case "${PAM_SERVICE:-}" in
                login)
                    MSG="local login,${hostname},${PAM_USER} logged off ${PAM_TTY}"
                    ;;
                sshd)
                    MSG="ssh,${hostname},${PAM_USER} logged off from ${PAM_RHOST}"
                    ;;
                *)
                    MSG="Abnormality,${hostname},${PAM_USER} logged off ${PAM_TTY} from ${PAM_RHOST} using ${PAM_SERVICE} and ${PAM_RUSER}"
                    ;;
            esac
            ;;
        *)
            STATE=open
            MSG="Abnormality,${hostname},Unhandled call to the logger. Data=${PAM_RHOST}, ${PAM_RUSER}, ${PAM_SERVICE}, ${PAM_TTY}, ${PAM_USER} and ${PAM_TYPE}"
            ;;
    esac
}

classify_escalation() {
    local hostname
    hostname="$(_notifier_hostname)"
    MSG=""
    STATE=""
    case "${PAM_TYPE:-}" in
        open_session)
            STATE=open
            _escalation_body "is impersonating"
            ;;
        close_session)
            STATE=close
            _escalation_body "is no longer impersonating"
            ;;
        *)
            STATE=open
            MSG="Abnormality,${hostname},Unhandled call to the logger. Data=${PAM_RHOST}, ${PAM_RUSER}, ${PAM_SERVICE}, ${PAM_TTY}, ${PAM_USER} and ${PAM_TYPE}"
            ;;
    esac
}

_escalation_body() {
    local verb hostname actor
    verb="$1"
    hostname="$(_notifier_hostname)"
    actor="${PAM_RUSER:-${SUDO_USER:-unknown}}"
    case "${PAM_SERVICE:-}" in
        sudo|su)
            if [[ "${PAM_USER}" == "root" ]]; then
                if [[ "${PAM_USER}" != "${PAM_RUSER}" ]]; then
                    MSG="${PAM_SERVICE},${hostname},${actor} ${verb} root on ${PAM_TTY}"
                fi
            else
                MSG="${PAM_SERVICE},${hostname},${actor} ${verb} ${PAM_USER} on ${PAM_TTY}"
            fi
            ;;
        *)
            if [[ "${STATE}" == "close" ]]; then
                MSG="Abnormality,${hostname},Unhandled impersonification end between ${PAM_RUSER} and ${PAM_USER} on ${PAM_TTY} (using service ${PAM_SERVICE} and host ${PAM_RHOST})"
            else
                MSG="Abnormality,${hostname},Unhandled impersonification between ${PAM_RUSER} and ${PAM_USER} on ${PAM_TTY} (using service ${PAM_SERVICE} and host ${PAM_RHOST})"
            fi
            ;;
    esac
}

dispatch_notify() {
    local notifier type host details
    if [[ -z "${MSG:-}" ]]; then
        return 0
    fi
    if ! notifier="$(find_notifier)"; then
        log_notifier "Failed to find notifier script"
        return 0
    fi
    type="${MSG%%,*}"
    host="${MSG#*,}"
    details="${host#*,}"
    host="${host%%,*}"
    "${notifier}" "${type}" "${host}" "${details}" "${STATE}" >/dev/null 2>&1 \
        || log_notifier "notifier exited $?"
    return 0
}
