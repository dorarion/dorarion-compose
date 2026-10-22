#!/usr/bin/env bash
set -euo pipefail
readonly root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly temporary="$(mktemp -d /tmp/dorarion-compose-check.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT
if docker compose version >/dev/null 2>&1; then
  compose() { docker compose "$@"; }
elif command -v docker-compose >/dev/null 2>&1; then
  compose() { docker-compose "$@"; }
else
  echo 'Docker Compose v2 is required for configuration validation.' >&2; exit 1
fi
export DORARION_ENV_FILE="$temporary/settings.env"
(umask 077; cat > "$DORARION_ENV_FILE" <<'ENV'
DORARION_IMAGE=example.invalid/dorarion:reviewed-test
POSTGRES_PASSWORD=configuration-test-only
JWT_SECRET=configuration-test-only-with-more-than-32-bytes
SECRET_ENCRYPTION_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
DORARION_COOKIE_SECURE=false
DORARION_EXT_TEST_TOKEN=external-test-credential
ENV
)
compose --project-directory "$root" --env-file "$DORARION_ENV_FILE" config --format json > "$temporary/config.json"
python3 - "$temporary/config.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))['services'];app=s['dorarion'];migration=s['migrate']
for service in (app,migration):
    e=service['environment'];assert e['DORARION_DATABASE_TRUSTED_HOSTS']=='postgres'
    assert e['DB_CONNECTION_POOL_SIZE']=='15' and e['DORARION_DB_STATEMENT_TIMEOUT_MS']=='30000'
    assert all(e.get(k) for k in ('JWT_SECRET','JWT_ISSUER','JWT_AUDIENCE','SECRET_ENCRYPTION_KEY'))
    assert e['DORARION_EXT_TEST_TOKEN']=='external-test-credential'
assert app['environment']['DORARION_MIGRATE_ON_START']=='false'
assert app['environment']['DORARION_COOKIE_SECURE']=='false'
assert app['healthcheck']['test']==['CMD','dorarion-core','healthcheck']
assert app['ports'][0]['host_ip']=='127.0.0.1'
assert app['stop_grace_period'].startswith('1m') or app['stop_grace_period']=='60s'
assert app['depends_on']['migrate']['condition']=='service_completed_successfully'
assert '@sha256:' in s['postgres']['image']
print('Compose trust, secrets, environment propagation, health, migration and port boundaries passed.')
PY
# Validate the release image from the installation example as well as overrides.
release_image="$(sed -n 's/^DORARION_IMAGE=//p' "$root/.env.docker.example")"
DORARION_IMAGE="$release_image" compose --project-directory "$root" --env-file "$DORARION_ENV_FILE" config --format json > "$temporary/release.json"
python3 - "$temporary/release.json" <<'PYRELEASE'
import json,sys
services=json.load(open(sys.argv[1]))['services']
expected='docker.io/kimc1992/dorarion-core:0.0.5@sha256:0dbc38be4c403cd2e7d9ac1bf29761364d9832063d3638ed8cfde06dba4e6061'
assert all(services[name]['image']==expected for name in ('dorarion','migrate'))
print('Compose release image pin verified for server and migration.')
PYRELEASE
# Simulate a failed migration: the updater must never replace the running app.
mkdir "$temporary/bin"
cat > "$temporary/bin/docker" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == 'compose version' ]]; then exit 0; fi
printf '%s\n' "$*" >> "$DORARION_TEST_DOCKER_LOG"
if [[ "$*" == *'run --rm migrate'* ]]; then exit 52; fi
exit 0
MOCK
chmod +x "$temporary/bin/docker"
export DORARION_TEST_DOCKER_LOG="$temporary/commands.log"
if PATH="$temporary/bin:$PATH" bash "$root/scripts/update-compose.sh" > "$temporary/update.log" 2>&1; then
  echo 'expected the failed migration to stop the update' >&2; exit 1
fi
if grep -q ' up ' "$DORARION_TEST_DOCKER_LOG"; then
  echo 'application replacement occurred after a failed migration' >&2; exit 1
fi
export DORARION_ENV_FILE="$temporary/new.env"
if PATH="$temporary/bin:$PATH" bash "$root/scripts/install-compose.sh" > "$temporary/install.log" 2>&1; then
  echo 'expected first-time setup to stop for private configuration' >&2; exit 1
fi
[[ "$(stat -c '%a' "$DORARION_ENV_FILE")" == 600 ]]
# Existing placeholders must stop installation before any Compose up command.
if PATH="$temporary/bin:$PATH" bash "$root/scripts/install-compose.sh" > "$temporary/install-again.log" 2>&1; then
  echo 'expected image/credential placeholders to stop installation' >&2; exit 1
fi
if grep -q ' up ' "$DORARION_TEST_DOCKER_LOG"; then
  echo 'installer launched unresolved placeholders' >&2; exit 1
fi
echo 'Compose script failure handling and private setup passed.'
