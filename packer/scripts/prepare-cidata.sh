#!/usr/bin/env bash
# Generates the cidata/ artifacts packer needs to SSH into the build VM:
#   - ssh_key + ssh_key.pub: ephemeral keypair only used during this
#     build; the resulting image has no record of it (cloud-init clean
#     wipes the seed). Both files are .gitignored.
#   - user-data: cloud-init config that authorizes the public key on the
#     stock `almalinux` user.
#   - meta-data: NoCloud datasource metadata (instance-id, hostname).
# Run before `packer build` (CI does this automatically).
set -euo pipefail

CIDATA_DIR="$(cd "$(dirname "$0")/../cidata" && pwd)"

if [[ ! -f "$CIDATA_DIR/ssh_key" ]]; then
  ssh-keygen -t ed25519 -N "" -C "packer-linux-base-image" -f "$CIDATA_DIR/ssh_key"
fi

cat > "$CIDATA_DIR/user-data" <<EOF
#cloud-config
users:
  - name: almalinux
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$CIDATA_DIR/ssh_key.pub")
ssh_pwauth: false
EOF

cat > "$CIDATA_DIR/meta-data" <<EOF
instance-id: linux-base-image-build
local-hostname: linux-base-image-build
EOF

echo "cidata ready in $CIDATA_DIR"
