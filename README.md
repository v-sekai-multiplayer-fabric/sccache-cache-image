# sccache-cache-image

V-Sekai compile cache VM image: versitygw serving an S3 endpoint for
[sccache](https://github.com/mozilla/sccache) to store + serve SCons-built
C++ object files for zone-baker, zone-server, godot-cpp, and other
Godot-engine builds. Run as a podman quadlet on top of `linux-base-image`.
Built once per release via packer; consumed by the `infra` repo as the
qcow2 for `harvester_virtualmachine.sccache`.

Separate from `restic-backup-image` because the workloads have different
shapes:

| | sccache | backup |
|---|---|---|
| Write cadence | constant (every build) | daily |
| Read cadence | constant (every CI run) | rare (DR only) |
| Eviction | LRU, churns | retention, never overwrites |
| Sensitivity | low (compile artifacts are reproducible) | high (only DR copy) |

Sharing one versitygw between them would let cache write pressure
evict backup capacity headroom, and an outage in one would take the
other down. Two VMs, two PVCs, two LB IPs.

## What's in the image

Inherits everything from `linux-base-image`, and adds:

- `/etc/containers/systemd/versitygw.container` — podman quadlet
  running versitygw against `/srv/sccache`
- `/srv/sccache` mountpoint (infra-side cloud-init binds a Harvester
  PVC here at first boot)
- `versitygw` system user owning the data directory

versitygw image pre-pulled into podman's local store. Tag pinned in
the quadlet; bumping is a deliberate edit + re-bake.

Service env file (`/etc/versitygw/env`) is not baked. The infra side
writes it at first boot with the sccache-specific access/secret pair
so this image is reusable across deployments.

## Client config

zone-baker / zone-server / godot CI configure sccache via env vars:

```sh
export SCCACHE_BUCKET=sccache
export SCCACHE_REGION=us-east-1
export SCCACHE_ENDPOINT=http://<sccache-lb-ip>:7070
export AWS_ACCESS_KEY_ID=<from infra tofu.tfvars>
export AWS_SECRET_ACCESS_KEY=<from infra tofu.tfvars>
sccache --start-server
```

Then SCons picks it up via `CC="sccache gcc"` / `CXX="sccache g++"`.

## Build

CI on push to main + weekly schedule. Local:

```sh
cd packer
bash scripts/prepare-cidata.sh
packer init build.pkr.hcl
packer build build.pkr.hcl
ls ../output/
```

## Inheritance

Pin the parent version explicitly in `build.pkr.hcl`:

```hcl
variable "source_image_url" {
  default = "https://github.com/v-sekai-multiplayer-fabric/linux-base-image/releases/download/v0.1.0/linux-base-image.qcow2"
}
```
