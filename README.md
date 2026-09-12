<!-- vim:set expandtab shiftwidth=2 filetype=markdown foldlevel=3: -->
<!-- SPDX-License-Identifier: GPL-3.0-only -->

<!--
   -
   - ~chewygumxx/systemd-override-gpg-socket.git
   - ::: :/README.md
   -
   -->

<!--
   - Adaptive GnuPG systemd socket resolution for custom GNUPGHOME.
   - Resolves hashed socket filepaths before initialisation.
   -->

# systemd-override-gpg-socket

Generates systemd user configuration overrides such that GnuPG `dirmngr`,
`keyboxd`, `gpg-agent`, `ssh`, `extra`, and `browser` sockets activate per paths
GnuPG *actually* computes for a non-default `GNUPGHOME`.

## The Problem

When the environment variable `GNUPGHOME` is set elsewhere from GnuPG's default
home directory, `gpgconf --list-dirs` computes hashed socket paths derived from
the new `GNUPGHOME` to avoid socket collision. Systemd user `.socket` units
shipped with the `gnupg` package are however, hardcoded to the *default* socket
paths within their `ListenStream=` directives. As such, defining a
non-conforming `GNUPGHOME` disassociates GnuPG socket references from their
systemd defined filepaths and the two never rendezvous: 
- Systemd activates sockets GnuPG clients will not interface.
- GnuPG clients reference socket paths systemd never created.

This repository mends that disharmony: A oneshot service runs before the
affected socket units, compares GnuPG's hashed socket paths against the systemd
`.socket` hardcoded paths, and generates ephemeral systemd overrides populated
with the freshly-computed `gpgconf --list-dirs` paths to re-associate.

## This Solution

1. `systemd-override-gpg-socket.service` is a oneshot service that executes the
   `systemd-override-gpg-socket` bash script before systemd initialises gpg
   sockets. Inert if `GNUPGHOME` is not set within systemd environment.
2. `systemd-override-gpg-socket` queries `gpgconf --list-dirs`, maps each
   resolved gpg `*-socket` to its corresponding systemd `.socket` unit, and
   writes a templated override file to its respective configuration directory:

   | `gpgconf --list-dirs` key | systemd unit               |
   |---------------------------|----------------------------|
   | `dirmngr-socket`          | `dirmngr.socket`           |
   | `keyboxd-socket`          | `keyboxd.socket`           |
   | `agent-socket`            | `gpg-agent.socket`         |
   | `agent-ssh-socket`        | `gpg-agent-ssh.socket`     |
   | `agent-extra-socket`      | `gpg-agent-extra.socket`   |
   | `agent-browser-socket`    | `gpg-agent-browser.socket` |
   
   ```
   $XDG_CONFIG_HOME/systemd/user/<unit>.socket.d/90-systemd-override-gpg-socket.conf
   ```
   A key with no matching *installed* unit is [logged](<#log>) and skipped rather
   than failing the run.

3. Stale `90-systemd-override-gpg-socket.conf` and the redundant empty
   directories they leave are cleaned up.
4. The path corrective overrides are registered and implemented with
   `systemctl --user daemon-reload`.

## Requirements

- `gpg`
- `systemd`
- `bash`
- `GNUPGHOME` exported into the **systemd user manager's** own environment, most
  conventionally via `~/.config/environment.d/*.conf` (exporting from shell rc
  files is ineffective).
- Directories `$XDG_CONFIG_HOME/systemd/user` or `~/.config/systemd/user` must
  already exist.

## Installation

```bash
# Clone this repository
git clone https://github.com/chewygumxx/systemd-override-gpg-socket.git
cd systemd-override-gpg-socket

# Install
install -Dm755 systemd-override-gpg-socket \
    "$HOME/.local/bin/systemd-override-gpg-socket"
install -Dm644 systemd-override-gpg-socket.service \
    "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/systemd-override-gpg-socket.service"

# Confirm 'GNUPGHOME' is set within systemd user manager environment and enable
# (Re-login is typically required after writing to "$XDG_CONFIG_HOME/environment.d/*.conf")
match="$(systemctl --user show-environment | grep "^GNUPGHOME=")"
case "$match" in
    GNUPGHOME=${HOME}/.gnupg)
        printf '%s\n' \
            "Almost o-o, GNUPGHOME is set within your systemd --user environment," \
            "but to the default directory:" \
            "" \
            "     $match" \
            "" \
        ;;
    GNUPGHOME=*)
        mkdir -p "${match#*=}"
        printf '%s\n' \
            "Success ^-^! GNUPGHOME is set within your systemd --user environment" \
            "" \
            "     $match" \
            "" \
            "Enable service?"

        select opt in yes no; do 
            [[ "$opt" == "yes" ]] && systemctl --user enable --now systemd-override-gpg-socket.service
            break
        done
        ;;
    *)
        printf '%s\n' \
            "Currently, no GNUPGHOME is set within your systemd --user environment." \
            "" \
            "1. Writing a file with the line:  GNUPGHOME=${HOME}/.local/share/gnupg" \
            "2. Saving that file to:           ~/.config/environment.d/gnupg.conf" \
            "3. Creating the directory with:   mkdir -p ${HOME}/.local/share/gnupg" \
            "4. And finally, logging out and back in may help." \
            "" \
            "    https://www.freedesktop.org/software/systemd/man/latest/environment.d.html" \
            ""
        ;;
esac
```

## Verification

```sh
systemctl --user status systemd-override-gpg-socket.service
systemctl --user cat    gpg-agent.socket
gpgconf   --list-dirs   agent-socket
```

The `ListenStream=` shown under the `90-systemd-override-gpg-socket.conf`
drop-in in `systemctl --user cat gpg-agent.socket` should match the path
`gpgconf --list-dirs agent-socket` reports.

### Log

```sh
journalctl --user -u systemd-override-gpg-socket.service
```

## Notes & Caveats

### Safe no-op without `GNUPGHOME`

If `GNUPGHOME` is unset within the manager's environment, both the service's
`ConditionEnvironment=` and the script's own guard skip execution entirely.
Stock GnuPG setups are unaffected.

### Changing `GNUPGHOME`

The hashed socket directory is derived from the resolved path of `GNUPGHOME`.
Redefining it requires re-running the service to regenerate the overrides.

```bash
systemctl --user restart systemd-override-gpg-socket.service
```

### Stale Override Cleanup

Overrides that provide for deprecated GnuPG hashed paths are removed upon next
execution. If removed the override leaves an empty directory, that directory is
removed also.

### Do not hand-edit the generated `.conf` files

They're regenerated on every run and are marked as such in their own header;
change the script, unit file, or write another override file alongside it
instead.

## License

[GPL-3.0-only](<./LICENSE>), see the SPDX header in each file.
