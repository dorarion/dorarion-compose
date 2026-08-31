# Dorarion Docker Compose

This distribution runs Dorarion with PostgreSQL 18, a persistent database volume and a one-shot SQLx migration service.

It defaults to the published `kimc1992/dorarion-core:0.0.3` image. Set
`DORARION_IMAGE` in `.env.docker` to select another immutable release tag;
application image builds remain in the `dorarion-core` repository.

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
password immediately in a password manager; it will not be shown again. The
command refuses to create an administrator when a login account already exists.

## Upgrade

Back up PostgreSQL, change `DORARION_IMAGE` in `.env.docker` to the new immutable release tag, then run:

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
