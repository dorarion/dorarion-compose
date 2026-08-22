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
  cp "$PROJECT_DIR/.env.docker.example" "$ENV_FILE"
  echo "Created $ENV_FILE"
  echo "Set strong POSTGRES_PASSWORD and JWT_SECRET values, then run this script again."
  exit 1
fi

if grep -qE '^(POSTGRES_PASSWORD|JWT_SECRET|SECRET_ENCRYPTION_KEY)=replace-' "$ENV_FILE"; then
  echo "Replace the placeholder POSTGRES_PASSWORD, JWT_SECRET, and SECRET_ENCRYPTION_KEY values in $ENV_FILE." >&2
  exit 1
fi

docker compose \
  --project-directory "$PROJECT_DIR" \
  --env-file "$ENV_FILE" \
  up --detach --pull always --wait

PORT="$(sed -n 's/^DORARION_PORT=//p' "$ENV_FILE" | tail -n 1)"
echo "Dorarion is available on http://localhost:${PORT:-3000}"
