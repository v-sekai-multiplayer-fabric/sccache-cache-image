#!/usr/bin/env bash
# Install the sccache versitygw S3 gateway podman quadlet onto this host.
#
# Copies the quadlet unit(s) in ./quadlets into the system quadlet
# directory, creates the cache data dir + owning user, optionally
# pre-pulls the pinned image, and reloads systemd.
#
# Service env file is NOT created here; deployments drop it at runtime:
#   /etc/versitygw/env  -> VERSITYGW_ACCESS, VERSITYGW_SECRET
#
# Run as root:  sudo ./install.sh
# Skip the pre-pull with:  PULL=0 sudo -E ./install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
QUADLET_DST=/etc/containers/systemd
PULL="${PULL:-1}"

[ "$(id -u)" -eq 0 ] || { echo "must run as root" >&2; exit 1; }

install -d -m 0755 "$QUADLET_DST"
install -m 0644 "$REPO_DIR"/quadlets/*.container "$QUADLET_DST"/

# Directory for the per-deployment env file referenced by the quadlet.
install -d -m 0755 /etc/versitygw

# Cache data lives on /srv/sccache, owned by a system user.
install -d -m 0750 /srv/sccache
useradd --system --shell /sbin/nologin --home-dir /srv/sccache versitygw || true
chown versitygw:versitygw /srv/sccache

if [ "$PULL" = "1" ]; then
  # Tag pinned in quadlets/versitygw.container.
  podman pull ghcr.io/versity/versitygw:v1.0.16
fi

systemctl daemon-reload
echo "Installed. Write /etc/versitygw/env, then: systemctl start versitygw.service"
