#!/bin/bash
# setup.sh — Run from WITHIN the immich-s23-heic-patch directory.
# Clones immich and base-images, then copies all patch files into place.
#
# Usage:
#   cd /path/to/immich-s23-heic-patch
#   bash setup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo " Immich S23 Ultra HEIC Patch — Setup"
echo "============================================"
echo ""
echo "Working directory: $SCRIPT_DIR"
echo ""

# Step 1: Clone official repos alongside this directory
if [ ! -d "immich" ]; then
    echo "→ Cloning immich..."
    git clone --depth 1 https://github.com/immich-app/immich.git immich
else
    echo "→ immich already exists — skipping clone"
fi

if [ ! -d "base-images" ]; then
    echo "→ Cloning base-images..."
    git clone https://github.com/immich-app/base-images.git base-images
else
    echo "→ base-images already exists — skipping clone"
fi

# Step 2: Prepare target directories
mkdir -p base-images/server/sources/libheif-patches
mkdir -p immich/docker

# Step 3: Copy patch files
echo ""
echo "→ Copying patches and build script..."
cp -v patches/*.patch                              base-images/server/sources/libheif-patches/
cp -v patches/libheif.sh                           base-images/server/sources/
cp -v Dockerfile.override                          immich/
cp -v docker/docker-compose.override.yml           immich/docker/
cp -v diagnose-heif.sh                             immich/

# Step 4: Add COPY line to base-images Dockerfile
echo ""
echo "→ Patching base-images Dockerfile..."
DOCKERFILE="base-images/server/Dockerfile"
if ! grep -q 'libheif-patches' "$DOCKERFILE"; then
    sed -i '/^COPY sources\/libheif\.json/a COPY sources/libheif-patches/ ./libheif-patches/' "$DOCKERFILE"
    echo "   Added COPY line to libheif stage."
else
    echo "   Already patched."
fi

echo ""
echo "============================================"
echo " Setup complete!"
echo "============================================"
echo ""
echo "Next steps (run from this directory):"
echo ""
echo "  # Build base images (~30 min)"
echo "  cd base-images"
echo "  docker build --no-cache -f server/Dockerfile -t base-server-dev:local --target dev server/"
echo "  docker build -f server/Dockerfile -t base-server-prod:local --target prod server/"
echo ""
echo "  # Build patched Immich (~3 min)"
echo "  cd ../immich"
echo "  docker build --no-cache -f Dockerfile.override -t immich-server-patched:latest ."
echo ""
echo "  # Configure and start"
echo "  cd docker"
echo "  cp example.env .env                       # create .env from template"
echo "  # Edit .env with your database password and upload path"
echo "  sed -i 's|image: ghcr.io/immich-app/immich-server:.*|image: immich-server-patched:latest|' docker-compose.yml"
echo "  docker compose up -d"
