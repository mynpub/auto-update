#!/usr/bin/env bash
set -Eeuo pipefail

REBOOT_MODE=always
NO_REBOOT=false
LOG_FILE=/var/log/auto-update.log

for arg in "$@"; do
    case "$arg" in
        --no-reboot) NO_REBOOT=true ;;
        --reboot-if-required) REBOOT_MODE=if-required ;;
        -h|--help)
            echo "Usage: $0 [--no-reboot] [--reboot-if-required]"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

if (( EUID != 0 )); then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

umask 027
exec 9>/var/lock/auto-update.lock
if ! flock -n 9; then
    echo "Another auto-update instance is already running." >&2
    exit 1
fi

# Check that logging can be opened before starting package maintenance.
: >> "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
trap 'log "ERROR: command failed at line $LINENO; aborting without scheduling a reboot." >&2' ERR

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

log "Starting Debian package maintenance."
apt-get -o APT::Update::Error-Mode=any update
apt-get "${APT_OPTS[@]}" upgrade
apt-get "${APT_OPTS[@]}" full-upgrade
apt-get "${APT_OPTS[@]}" autoremove --purge
apt-get "${APT_OPTS[@]}" autoclean
log "Package maintenance completed successfully."

if "$NO_REBOOT"; then
    log "Skipping reboot (--no-reboot)."
elif [[ $REBOOT_MODE == if-required && ! -e /var/run/reboot-required ]]; then
    log "No reboot-required marker found; skipping reboot."
else
    log "Scheduling a reboot in one minute."
    shutdown -r +1 "Rebooting after automatic Debian package updates"
fi
