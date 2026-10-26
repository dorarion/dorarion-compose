# Dorarion Docker Compose

This distribution runs Dorarion with PostgreSQL 18, a persistent database volume and a one-shot SQLx migration service.

The example `.env.docker` selects Docker Hub core `kimc1992/dorarion-core:0.0.7`,
pinned to the verified linux/amd64 manifest:
`sha256:3612981b1db1fc898311eaeb091c15964737b25ab31504c5ac6086d5d896a2c2`.
Use an amd64 Docker host. Both the server and migration service use this image.
Never combine a new tag with an older image's digest: the digest takes precedence.
Keep release tags immutable and publish fixes under a new tag.
Application image builds remain in `dorarion-core`.

Compose runs core and PostgreSQL. The optional listener `0.0.1` is tested through
the Helm chart; this Compose distribution does not deploy a receiver or watcher.

The install script uses local images when present; the update script pulls the
selected registry image and therefore expects a published reviewed artifact.

## Installation guides

For a complete Windows installation using WSL 2 and Docker:

- [English](docs/installation-windows-wsl.md)
- [한국어](docs/installation-windows-wsl-ko.md)
- [简体中文](docs/installation-windows-wsl-zh-cn.md)

## Install

```bash
./scripts/install-compose.sh
```

The first run creates `.env.docker` and stops. Its application settings mirror
the variables documented by `dorarion-core/.env`. Replace the placeholder
database password, JWT secret, and encryption key, then run the script again.

## Create the first administrator

After the installation is healthy, create the first administrator once:

```bash
docker compose --env-file .env.docker run --rm dorarion \
  bootstrap-admin admin admin@example.com
```

Dorarion generates a random password and prints it in the terminal. Save the
password immediately in a password manager; it will not be shown again.
The generated password must be changed at the first login. The
command refuses to create an administrator when a login account already exists.

## Upgrade

Back up PostgreSQL and change `DORARION_IMAGE` in your existing `.env.docker`
to the new release image. Updating `.env.docker.example` does not update an
existing installation. For this release use
`docker.io/kimc1992/dorarion-core:0.0.7@sha256:3612981b1db1fc898311eaeb091c15964737b25ab31504c5ac6086d5d896a2c2`.
Replace the entire value, including any older digest, then run:

```bash
./scripts/update-compose.sh
```

The update stops before replacing the application if its migration fails.

## Operations

```bash
docker compose --env-file .env.docker ps
docker compose --env-file .env.docker logs --follow dorarion
docker compose --env-file .env.docker down
```

Database deletion is intentionally explicit:

```bash
docker compose --env-file .env.docker down --volumes
```

## Runtime and upgrade policy

The database host postgres is explicitly trusted only on the internal Compose
network. The database image is digest-pinned; do not silently change its major
version or delete its volume. DB_CONNECTION_POOL_SIZE defaults to 15, plus six
separate worker connections. DORARION_DB_STATEMENT_TIMEOUT_MS defaults to 30000.

The migration service references the required JWT and encryption settings and
runs once before serving. DORARION_MIGRATE_ON_START=false prevents a second startup
migration. The native dorarion-core healthcheck needs no curl in the image.
Readiness checks PostgreSQL; authenticated /health/workers reports workers
separately. The server has 60 seconds to stop gracefully.

.env.docker is kept private (0600) and also supplied as the container environment
file. Additional DORARION_EXT_ credentials, monitoring tokens, proxy networks,
recipient domains and README image origins therefore reach the core. Legacy
external environment names need DORARION_SECRET_ENV_ALLOWLIST; core secrets are
always denied. DORARION_README_IMAGE_ORIGINS is empty by default and accepts exact
HTTPS provider origins. Store a random 32–512-character ASCII
DORARION_METRICS_SCRAPE_TOKEN for Prometheus and send it only to /metrics.

The published port binds to 127.0.0.1 by default. Local HTTP requires
DORARION_COOKIE_SECURE=false, as shown in the example. For a reverse proxy, set an
HTTPS DORARION_PUBLIC_URL, secure cookies and narrowly scoped trusted proxy CIDRs.
Set DORARION_BIND_ADDRESS deliberately if the proxy is on another host.

Before upgrading, back up PostgreSQL and the exact SECRET_ENCRYPTION_KEY. Read
migration pre-checks, rotate per-application Argo CD reporting tokens, replace the
global incident token with scoped incident sources, and review the bundled API
contract. Run `bash tests/check.sh` to validate configuration and script failure
handling; it does not start containers or establish live deployment acceptance.

## Beta database baseline — 2026-10-10

The reviewed core source now installs two consolidated migrations. Earlier beta
databases require a new empty database or an explicit data-losing reinstall; this
is not an in-place migration from the previous 80-file chain. Do not delete only
the SQLx ledger or reuse an earlier image after initializing the new schema.
See the core migrations/README.md for the reinstall procedure. Existing data is
not automatically deleted by Compose scripts or Helm hooks. Build a fresh image
from the reviewed source and use a new immutable tag/digest. Listener is optional.


## Private network access

Set `DORARION_ALLOWED_PRIVATE_PROVIDER_HOSTS=gitlab.corp.example` and, separately,
`DORARION_ALLOWED_PRIVATE_WEBHOOK_HOSTS=hooks.corp.example` in the private
`.env.docker` file. Compose forwards them through `env_file` to core and CLI
services. Prefer these over `ALLOW_PRIVATE_WEBHOOK_DESTINATIONS`, which is
deprecated. Values are comma-separated exact hostnames, IP addresses, or CIDRs;
do not include URL schemes, paths (except CIDR), or hostname ports. For example,
use `gitlab.corp.example`, not `gitlab.corp.example:8443`; the GitLab URL itself
may include port 8443. DNS, trusted CA certificates, and network access must also
be configured independently.

## Restore into an empty database

Stop all application writers and receivers. Preserve the encryption key and
restore the dump into a new, empty PostgreSQL database, then point the installation
at it. Keep the original database until recovery is verified. Run the matching
image's migration service and verify readiness before resuming traffic.
Do not restore an older dump over a newer database using
`pg_restore --clean --if-exists`: objects absent from the dump can survive while
the migration ledger is restored to an older state, breaking the next upgrade.
