#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "Stopping Wazuh single-node (if running)..."
if [ -f "$ROOT_DIR/../wazuh/config/wazuh-docker/single-node/docker-compose.yml" ]; then
  docker compose -f "$ROOT_DIR/../wazuh/config/wazuh-docker/single-node/docker-compose.yml" down || true
else
  echo "Wazuh single-node compose not found in repo."
fi

echo "Stopping Shuffle stack (if running)..."
if [ -d "$ROOT_DIR/../shuffle/Shuffle" ]; then
  cd "$ROOT_DIR/../shuffle/Shuffle"
  docker compose down || true
else
  echo "Shuffle directory not found."
fi

echo "Stopping Wazuh forwarder (if present)..."
cd "$ROOT_DIR/wazuh-forwarder"
if [ -f docker-compose.yml ]; then
  docker compose down || true
else
  echo "No forwarder compose found in $PWD"
fi

echo "All stacks stopped."
