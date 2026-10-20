# auto-update

Unattended package maintenance for Debian servers. `auto-update.sh` refreshes
configured APT repositories, runs `upgrade` and `full-upgrade`, removes unused
packages with `autoremove --purge`, and cleans obsolete cached packages with
`autoclean`. By default, it then schedules a reboot in one minute.

## Prerequisites and safety

- Debian with Bash, APT, `flock` (from `util-linux`), `tee` (from `coreutils`),
  and `shutdown` (normally provided by `systemd-sysv`).
- Run as root. Keep the installed script and its parent directory writable only
  by root, and configure trusted APT repositories.
- Back up important data and test on a noncritical server first. Full upgrades
  can remove packages; autoremove purges unused packages and their configuration.
  This is not a Debian release-upgrade tool.
- Updates are noninteractive. Dpkg uses default configuration decisions where
  available, otherwise keeping local configuration; UCF also keeps local files.
  If installed, `needrestart` automatically restarts affected services. Expect
  service interruptions even with `--no-reboot`. Custom package scripts may not
  honor noninteractive settings.
- A lock at `/var/lock/auto-update.lock` rejects overlapping script runs. Other
  package managers still use their own APT/dpkg locks; contention can cause this
  script to fail. Package errors (including repository refresh errors) stop
  subsequent steps and prevent this run from scheduling a reboot. Completed
  package changes are not rolled back.

## Installation and usage

From the repository directory:

```sh
sudo install -o root -g root -m 0755 auto-update.sh /usr/local/sbin/auto-update.sh
sudo /usr/local/sbin/auto-update.sh --no-reboot
```

Reboot modes:

```sh
sudo /usr/local/sbin/auto-update.sh                      # Always reboot on success
sudo /usr/local/sbin/auto-update.sh --reboot-if-required  # Only if the marker exists
sudo /usr/local/sbin/auto-update.sh --no-reboot           # Never schedule a reboot
```

If both flags are supplied, `--no-reboot` takes precedence regardless of order.
`--help` prints usage; unknown options are rejected.

`--reboot-if-required` checks `/var/run/reboot-required`. Not all Debian packages
create this marker, so its absence does not guarantee a reboot is unnecessary.
Reboots use `shutdown -r +1` to provide a one-minute warning; root can cancel a
pending reboot with `shutdown -c`. The script does not cancel reboots scheduled
by other processes or prevent package-specific reboot behavior.

## Weekly scheduling and logs

Use `sudo crontab -e` to add this **root crontab** entry for Sundays at 03:00
(server local time):

```cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 3 * * 0 /usr/local/sbin/auto-update.sh --reboot-if-required >/dev/null 2>&1
```

Omit the flag to reboot after every successful run, or use `--no-reboot` to
manage reboots separately. Choose a maintenance window with room for downtime.

Once logging is initialized, stdout and stderr go to both the console and
`/var/log/auto-update.log` (append-only). Early argument, privilege, lock, or
logging initialization failures go to the invoking terminal/cron stderr.
Monitor failures and configure log rotation separately to limit disk usage.