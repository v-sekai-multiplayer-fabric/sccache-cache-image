# sccache-cache-quadlet

Podman [quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
source for a versitygw S3 endpoint backing
[sccache](https://github.com/mozilla/sccache) — stores + serves
SCons-built C++ object files for zone-baker, zone-server, godot-cpp, and
other Godot-engine builds. Run by systemd on an AlmaLinux host.

This repo is the source of truth for the unit; it is installed onto a
host rather than baked into a VM image.

Kept separate from `restic-backup-quadlet` because the workloads differ:

| | sccache | backup |
|---|---|---|
| Write cadence | constant (every build) | daily |
| Read cadence | constant (every CI run) | rare (DR only) |
| Eviction | LRU, churns | retention, never overwrites |
| Sensitivity | low (reproducible artifacts) | high (only DR copy) |

## Layout

- `quadlets/versitygw.container` — versitygw against `/srv/sccache`,
  publishes `7070`. Tag pinned here.
- `install.sh` — installs the unit, creates `/srv/sccache` and the
  owning `versitygw` user, pre-pulls the image, reloads systemd.

## Install

```sh
sudo ./install.sh
# write /etc/versitygw/env (see below)
sudo systemctl start versitygw.service
```

## Configuration (per-deployment, NOT in this repo)

- `/etc/versitygw/env` — `VERSITYGW_ACCESS`, `VERSITYGW_SECRET`.

## Client config

```sh
export SCCACHE_BUCKET=sccache
export SCCACHE_REGION=us-east-1
export SCCACHE_ENDPOINT=http://<sccache-host-ip>:7070
export AWS_ACCESS_KEY_ID=<access>
export AWS_SECRET_ACCESS_KEY=<secret>
sccache --start-server
```

Then SCons picks it up via `CC="sccache gcc"` / `CXX="sccache g++"`.

## CI

`.github/workflows/lint.yml` validates the unit via podman's systemd
generator on every push/PR.
