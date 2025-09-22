#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

AGENT_CONTAINER_NAME="wazuh-agent"
if docker ps --format '{{.Names}}' | grep -q "${AGENT_CONTAINER_NAME}"; then
  echo "Running brute-force simulation inside container ${AGENT_CONTAINER_NAME}..."
  docker exec -it "${AGENT_CONTAINER_NAME}" bash -c '
for i in {1..50}; do
  echo "invalidpass" | sudo -S -u nobody false >/dev/null 2>&1 || true
done'
else
  echo "Agent container '${AGENT_CONTAINER_NAME}' not found. You can run an agent using the official Wazuh agent compose or adjust AGENT_CONTAINER_NAME."
fi
