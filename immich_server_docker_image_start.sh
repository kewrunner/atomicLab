#!/usr/bin/env bash
set -Eeuo pipefail

IMMICH_DIR="/media/flowzine/8f10bcc6-c0e3-4c12-ab4a-23642d06cc7a4/home/flowzine/immich-app"
COMPOSE_BIN="docker compose"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

[[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose plugin not found."; exit 1; }

log "Stopping all running containers..."
docker ps -q | xargs -r docker stop

log "Removing all containers..."
docker ps -aq | xargs -r docker rm -f

log "Starting Immich only..."
cd "${IMMICH_DIR}"
${COMPOSE_BIN} up -d

log "Final status:"
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'