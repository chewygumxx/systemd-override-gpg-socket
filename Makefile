# vim:set noexpandtab tabstop=4 shiftwidth=4 filetype=make:
# SPDX-License-Identifier: GPL-3.0-only

#
#
# ~chewygumxx/systemd-override-gpg-socket.git
# ::: :/Makefile
#
#

#
# Installs systemd-override-gpg-socket into the current user's own
# XDG directories.
#

SCRIPT  := systemd-override-gpg-socket
UNIT    := systemd-override-gpg-socket.service

BINDIR    := $(HOME)/.local/bin
CONFIGDIR := $(or $(XDG_CONFIG_HOME),$(HOME)/.config)
UNITDIR   := $(CONFIGDIR)/systemd/user

.PHONY: all install uninstall enable disable check-gnupghome

all: check-gnupghome enable

install:
	install -Dm755 $(SCRIPT)  "$(BINDIR)/$(SCRIPT)"
	install -Dm644 $(UNIT)   "$(UNITDIR)/$(UNIT)"
	systemctl --user daemon-reload

enable: install
	systemctl --user enable --now $(UNIT)

disable:
	-systemctl --user disable --now $(UNIT)

uninstall: disable
	rm -f "$(BINDIR)/$(SCRIPT)" "$(UNITDIR)/$(UNIT)"
	systemctl --user daemon-reload

check-gnupghome:
	@match="$$(systemctl --user show-environment | grep '^GNUPGHOME=')"; \
	case "$$match" in \
		GNUPGHOME=$(HOME)/.gnupg) \
			printf '%s\n' \
				"Almost o-o, GNUPGHOME is set within your systemd --user environment," \
				"but to the default directory:" \
				"" \
				"     $$match" \
				""; \
			exit 1 \
			;; \
		GNUPGHOME=*) \
			mkdir -m 700 -p "$${match#*=}"; \
			printf '%s\n' \
				"Success ^-^! GNUPGHOME is set within your systemd --user environment" \
				"" \
				"     $$match" \
				""; \
			;; \
		*) \
			printf '%s\n' \
				"Currently, no GNUPGHOME is set within your systemd --user environment." \
				"" \
				"  1. Writing a file with the line:  GNUPGHOME=${HOME}/.local/share/gnupg" \
				"  2. Saving that file to:           ~/.config/environment.d/gnupg.conf" \
				"  3. Creating the directory with:   mkdir -p ${HOME}/.local/share/gnupg" \
				"  4. And finally, logging out and back in may help." \
				"" \
				"     https://www.freedesktop.org/software/systemd/man/latest/environment.d.html" \
				""; \
			exit 1 \
			;; \
	esac
