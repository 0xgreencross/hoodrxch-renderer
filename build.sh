#!/bin/sh
cd "$(dirname "$0")"
cat src/00_head.html src/01_keccak.js src/02_glyphs.js src/03_geom.js src/04_genesis.js src/05_render.js src/06_ui.js > reference-renderer/index.html
echo "built $(wc -c < reference-renderer/index.html) bytes"
