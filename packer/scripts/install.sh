#!/usr/bin/env bash
# Provisioner: layers sccache-cache bits on top of linux-base-image.
# Runs as root via `sudo -E bash`.
set -euo pipefail

# Quadlet files placed by the packer file provisioner go to the system
# quadlet directory where podman's systemd generator picks them up at
# boot.
install -d -m 0755 /etc/containers/systemd
install -m 0644 /tmp/quadlets/*.container /etc/containers/systemd/
rm -rf /tmp/quadlets

# Pre-pull the versitygw image so first boot doesn't wait on network.
# Tag pinned here; bumping is a deliberate change to this repo (and
# re-bake).
podman pull ghcr.io/versity/versitygw:v1.0.16

# Cache data lives on /srv/sccache. Create the mountpoint and a
# system user that owns it. The infra side bind-mounts a Harvester PVC
# here via cloud-init at first boot.
install -d -m 0750 /srv/sccache
useradd --system --shell /sbin/nologin --home-dir /srv/sccache versitygw || true
chown versitygw:versitygw /srv/sccache

dnf clean all
cloud-init clean --logs
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id || true
fstrim -av || true
