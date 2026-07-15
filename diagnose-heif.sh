#!/bin/bash
# diagnose-heif.sh — Run inside the immich_server container:
#   docker cp diagnose-heif.sh immich_server:/tmp/
#   docker exec immich_server bash /tmp/diagnose-heif.sh

echo "============================================"
echo " HEIC/LIBHEIF DIAGNOSTIC"
echo "============================================"

echo ""
echo "--- 1. All libheif files on the system ---"
find / -name "libheif*" -type f 2>/dev/null | sort

echo ""
echo "--- 2. libheif loaded by libvips ---"
echo "  Checking: ldd /usr/local/lib/libvips.so.42 | grep heif"
ldd /usr/local/lib/libvips.so.42 2>/dev/null | grep -i heif || echo "  (none)"

echo ""
echo "--- 3. libvips heif module ---"
echo "  Module directory:"
find /usr/local/lib -path "*/vips-modules-*" -name "*.so" 2>/dev/null | sort
echo ""
echo "  What does the heif module link to?"
MODULE=$(find /usr/local/lib -path "*/vips-modules-*/heif*.so" 2>/dev/null | head -1)
if [ -n "$MODULE" ]; then
    echo "  Module: $MODULE"
    ldd "$MODULE" 2>/dev/null | grep -E "heif|vips" || echo "  (no heif/vips links found)"
else
    echo "  NO heif module found! This is the problem."
fi

echo ""
echo "--- 4. Patched values in libheif ---"
LIBHEIF=$(find /usr/local/lib -name "libheif.so*" -not -name "*.a" 2>/dev/null | head -1)
if [ -n "$LIBHEIF" ]; then
    echo "  Checking: $LIBHEIF"
    echo "  max_items (expect 2048):"
    if strings "$LIBHEIF" 2>/dev/null | grep -q "2048"; then
        echo "    -> value 2048 FOUND - libheif IS PATCHED"
    else
        echo "    -> NOT FOUND - libheif is UNPATCHED"
    fi
else
    echo "  libheif.so not found in /usr/local/lib!"
fi

echo ""
echo "--- 5. Sharp version check ---"
node -e "try{const s=require('/usr/src/app/server/node_modules/sharp');console.log('  sharp:',s.versions.sharp);console.log('  libvips:',s.versions.vips);console.log('  SHARP_FORCE_GLOBAL_LIBVIPS:',process.env.SHARP_FORCE_GLOBAL_LIBVIPS||'NOT SET')}catch(e){console.log('  Sharp not found:',e.message)}"

echo ""
echo "--- 6. vips version ---"
vips --version 2>/dev/null || echo "  vips binary not found"

echo ""
echo "============================================"
echo " If step 4 shows 'FOUND', libheif is patched."
echo " If step 3 shows NO heif module, libvips"
echo " is missing heif support entirely."
echo "============================================"
