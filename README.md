# Immich — Samsung S23 Ultra HEIC Patch (200MP)

Adds support for high-resolution HEIC images from the **Samsung Galaxy S23 Ultra**
(200 megapixel mode) to [Immich](https://github.com/immich-app/immich).

Everything happens inside this directory. The official repos are cloned here
automatically by `setup.sh`.

---

## The Problem

Samsung S23 Ultra HEIC files contain ~576–579 internal items. libheif's box
parser rejects anything above 256:

```
Security limit exceeded: ipma box wants to define properties for 578 items,
but the security limit has been set to 256 items
```

Three checks are affected:

| Box  | Samsung count | libheif default | Our fix |
|------|--------------|-----------------|---------|
| ipma | ~578         | 256             | 10,000  |
| iloc | ~579         | 256             | 10,000  |
| iref | ~576         | 256             | 10,000  |

---

## Prerequisites

- Linux with Docker
- ~15 GB free disk space
- Internet connection

---

## Setup (Copy-Paste)

All commands run from **inside this directory**.

```bash
cd /path/to/immich-s23-heic-patch

# 1. Clone the official repos and copy patches into place
bash setup.sh

# 2. Build base images (~30 minutes)
cd base-images
docker build --no-cache -f server/Dockerfile \
  -t base-server-dev:local --target dev server/
docker build -f server/Dockerfile \
  -t base-server-prod:local --target prod server/

# 3. Build patched Immich (~3 minutes)
cd ../immich
docker build --no-cache -f Dockerfile.override \
  -t immich-server-patched:latest .

# 4. Configure and start
cd docker
mkdir -p upload postgres model-cache       # local data directories
cp example.env .env                       # create .env from template
# Edit .env with your settings (database password, upload location, etc.)
# nano .env

sed -i 's|image: ghcr.io/immich-app/immich-server:.*|image: immich-server-patched:latest|' docker-compose.yml
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d

# 5. Verify
docker exec immich_server node -e \
  "const s=require('/usr/src/app/server/node_modules/sharp'); \
   console.log('libvips:', s.versions.vips)"
```

Expected: `libvips: 8.18.4`

Upload a Samsung HEIC — thumbnails generate without errors.

---

## What Each File Does

| File | Purpose |
|------|---------|
| `setup.sh` | Clones immich + base-images, copies patches, patches Dockerfiles |
| `patches/0001-*.patch` | `security_limits.cc`: max_items 1000 -> 2048, max_children_per_box 100 -> 512 |
| `patches/0004-*.patch` | `box.cc`: hardcodes ipma/iloc/iref checks to 10,000 |
| `patches/libheif.sh` | Build script: clones libheif, applies patches, compiles |
| `Dockerfile.override` | Takes official Immich image, swaps in patched libheif |
| `docker/docker-compose.override.yml` | Sets SHARP_FORCE_GLOBAL_LIBVIPS + LD_LIBRARY_PATH |
| `diagnose-heif.sh` | Diagnostic tool — run inside the container |

---

## How It Works

```
Samsung HEIC -> Immich -> Sharp -> libvips -> vips-heif.so -> libheif (PATCHED)
                                                              |
                                    ipma / iloc / iref ------+ hardcoded to 10,000
```

The `Dockerfile.override` takes the official release image (Sharp is already
compiled with `SHARP_FORCE_GLOBAL_LIBVIPS=true`) and replaces only `libheif.so`,
`libde265.so`, and `vips-modules/` from our patched base image. No Sharp rebuild.

---

## Tested Versions

This patch has been successfully tested with:

| Component | Version |
|-----------|---------|
| **Immich Server** | v3.0.2 |
| **libheif** | Patched version (built from source) |
| **Sharp** | Included in Immich server image |
| **libvips** | 8.18.4 (verified) |

The patch runs without issues on Immich server version V3.0.2, providing full support for Samsung S23 Ultra 200MP HEIC files.

---

## Updating

```bash
cd /path/to/immich-s23-heic-patch/immich
docker pull ghcr.io/immich-app/immich-server:release
docker build --no-cache -f Dockerfile.override -t immich-server-patched:latest .
cd docker && docker compose up -d --force-recreate immich-server
```

---

## Troubleshooting

```bash
# Diagnostic inside container
docker cp diagnose-heif.sh immich_server:/tmp/
docker exec immich_server bash /tmp/diagnose-heif.sh

# Watch for errors during upload
docker compose -f docker-compose.yml -f docker-compose.override.yml logs -f immich-server | grep -i "security limit"
```

---

Made with ❤️ for the Linux Community
```
