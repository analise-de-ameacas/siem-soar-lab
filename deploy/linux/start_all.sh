#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "Ensure Docker network 'siem-net' exists..."
if ! docker network inspect siem-net >/dev/null 2>&1; then
  docker network create siem-net
fi

echo "Starting Wazuh single-node (official compose)..."
if [ -f "$ROOT_DIR/../wazuh/config/wazuh-docker/single-node/docker-compose.yml" ]; then
  docker compose -f "$ROOT_DIR/../wazuh/config/wazuh-docker/single-node/docker-compose.yml" up -d
else
  echo "Wazuh single-node compose not found in repo. Please place official compose at wazuh/config/wazuh-docker/single-node/docker-compose.yml"
fi

echo "Starting Shuffle stack..."
cd "$ROOT_DIR/../shuffle/Shuffle"
docker compose down || true
docker compose up -d

echo "Waiting for Wazuh API to be available (this may take 2-4 minutes)..."
WAZUH_API_PORT=55000
MAX_ATTEMPTS=120
SLEEP_SECS=2

# try to locate manager container name
MANAGER_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'wazuh.manager|single-node-wazuh.manager' || true)
if [ -z "$MANAGER_CONTAINER" ]; then
  echo "Could not find a running Wazuh manager container by name, will try localhost:55000"
else
  echo "Detected Wazuh manager container: $MANAGER_CONTAINER"
  MANAGER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$MANAGER_CONTAINER" 2>/dev/null || true)
  echo "Manager container IP: ${MANAGER_IP:-not-found}"
fi

attempt=1
success=0
while [ $attempt -le $MAX_ATTEMPTS ]; do
  echo "Attempt $attempt/$MAX_ATTEMPTS: checking Wazuh API..."

  # 1) try HTTPS on localhost (published port)
  if curl -k --max-time 3 -sS -o /dev/null -w "%{http_code}" https://localhost:$WAZUH_API_PORT/ 2>/dev/null | grep -E "^[23]" >/dev/null; then
    echo "Wazuh API reachable via https://localhost:$WAZUH_API_PORT"
    success=1; break
  fi

  # 2) try HTTP on localhost
  if curl -sS --max-time 3 -o /dev/null -w "%{http_code}" http://localhost:$WAZUH_API_PORT/ 2>/dev/null | grep -E "^[23]" >/dev/null; then
    echo "Wazuh API reachable via http://localhost:$WAZUH_API_PORT"
    success=1; break
  fi

  # 3) try container IP (https then http)
  if [ -n "${MANAGER_IP:-}" ]; then
    if curl -k --max-time 3 -sS -o /dev/null -w "%{http_code}" https://$MANAGER_IP:$WAZUH_API_PORT/ 2>/dev/null | grep -E "^[23]" >/dev/null; then
      echo "Wazuh API reachable via https://$MANAGER_IP:$WAZUH_API_PORT"
      success=1; break
    fi
    if curl -sS --max-time 3 -o /dev/null -w "%{http_code}" http://$MANAGER_IP:$WAZUH_API_PORT/ 2>/dev/null | grep -E "^[23]" >/dev/null; then
      echo "Wazuh API reachable via http://$MANAGER_IP:$WAZUH_API_PORT"
      success=1; break
    fi
  fi

  # 4) as a fallback, check container logs for APID started
  if [ -n "$MANAGER_CONTAINER" ]; then
    if docker logs --since 5m "$MANAGER_CONTAINER" 2>/dev/null | grep -i "Started wazuh-apid" >/dev/null; then
      echo "Found 'Started wazuh-apid' in manager logs (assume API ready)"
      success=1; break
    fi
  fi

  attempt=$((attempt+1))
  sleep $SLEEP_SECS
done

if [ $success -ne 1 ]; then
  echo "Wazuh API did not become ready after $((MAX_ATTEMPTS*SLEEP_SECS)) seconds. Check manager logs:"
  if [ -n "$MANAGER_CONTAINER" ]; then
    docker logs --tail 200 "$MANAGER_CONTAINER" || true
  fi
  echo "Continuing anyway; forwarder start may fail."
fi

echo "Starting Wazuh forwarder (if present)..."
cd "$ROOT_DIR/wazuh-forwarder"
if [ -f docker-compose.yml ]; then
  docker compose up -d --build
else
  echo "No forwarder compose found in $PWD"
fi

echo "All stacks triggered. Use 'docker ps' to inspect running containers."
