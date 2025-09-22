#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Ensuring shuffle host folders exist and owned by uid 1000..."
SHUFFLE_DIR="$ROOT_DIR/../shuffle/Shuffle"
DATA_DIR="$SHUFFLE_DIR/shuffle-database"
APPS_DIR="$SHUFFLE_DIR/shuffle-apps"
FILES_DIR="$SHUFFLE_DIR/shuffle-files"

mkdir -p "$DATA_DIR" "$APPS_DIR" "$FILES_DIR"
chown -R 1000:1000 "$DATA_DIR" || true
chown -R 1000:1000 "$APPS_DIR" || true
chown -R 1000:1000 "$FILES_DIR" || true

echo "Done."
