#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${DORARION_ENV_FILE:-$PROJECT_DIR/.env.docker}"

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker with the Compose v2 plugin is required." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE; run scripts/install-compose.sh first." >&2
  exit 1
fi

compose() {
  docker compose --project-directory "$PROJECT_DIR" --env-file "$ENV_FILE" "$@"
}

compose pull dorarion migrate

# Stop immediately if the forward migration fails. The running application is
# left untouched until the new schema has been applied successfully.
compose run --rm migrate
compose up --detach --remove-orphans --wait dorarion

echo "Dorarion update completed."
