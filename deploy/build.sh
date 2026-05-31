#!/usr/bin/env bash
# Build the site into the directory nginx serves.
#
#   ./deploy/build.sh [OUT_DIR]
#
# Defaults to /srv/www/igou.io. Uses a host `hugo` if present, otherwise falls
# back to a one-shot podman Hugo container (set FORCE_PODMAN=1 to force it).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-/srv/www/igou.io}"

mkdir -p "$OUT_DIR"

if [[ "${FORCE_PODMAN:-0}" != "1" ]] && command -v hugo >/dev/null 2>&1; then
  echo "Building with host hugo -> $OUT_DIR"
  hugo --minify --source "$REPO" --destination "$OUT_DIR" --cleanDestinationDir
else
  echo "Building with podman one-shot hugo -> $OUT_DIR"
  podman run --rm \
    -v "$REPO":/src:ro,Z \
    -v "$OUT_DIR":/out:Z \
    docker.io/hugomods/hugo:latest \
    hugo --minify --source /src --destination /out --cleanDestinationDir
fi

echo "Done."
