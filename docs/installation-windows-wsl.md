# WSL 2 + Docker + Dorarion

Simple local installation guide

> **Goal:** Install Ubuntu in WSL 2, install Docker, clone Dorarion, generate its required secrets, create the first administrator, and open Dorarion in your Windows browser.

- Run Windows commands in PowerShell as Administrator.
- Run Linux and Docker commands inside the Ubuntu WSL terminal.
- This guide follows the Dorarion Compose workflow used successfully on a local machine.
- A [PDF version](pdf/dorarion-wsl-docker-install-en.pdf) is also available.

## 1. Install WSL 2 and Ubuntu

Open PowerShell as Administrator and run:

```powershell
wsl --install -d Ubuntu
```

Restart Windows if asked. Then open Ubuntu from the Start menu and create your Linux username and password.

Optional check from PowerShell:

```powershell
wsl -l -v
```

Ubuntu should show `VERSION 2`.

## 2. Prepare Ubuntu

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y git openssl ca-certificates curl
```

## 3. Install Docker Engine and Compose

### 3.1 Remove old or conflicting Docker packages

```bash
sudo apt remove -y docker.io docker-compose docker-compose-v2 \
  docker-doc docker-buildx podman-docker containerd runc
```

### 3.2 Add Docker's official repository

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

### 3.3 Install and test Docker

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo docker run --rm hello-world
docker --version
docker compose version
```

The commands below use `sudo` with Docker. That is fine for this local installation and avoids Docker socket permission problems.

## 4. Download Dorarion

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/dorarion/dorarion-compose.git
cd dorarion-compose
```

## 5. Prepare Dorarion

Run Dorarion's Compose installer once. It prepares the Compose environment, including `.env.docker`:

```bash
./scripts/install-compose.sh
```

Check the environment file:

```bash
cat .env.docker
```

If `.env.docker` is owned by root, and only if you get a permission error while editing the file, run:

```bash
sudo chown "$USER:$USER" .env.docker
```

## 6. Generate Dorarion secrets

Run these commands in the `dorarion-compose` directory:

```bash
POSTGRES_PASSWORD="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 32)"
SECRET_ENCRYPTION_KEY="$(openssl rand -base64 32)"

sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env.docker
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env.docker
sed -i "s|^SECRET_ENCRYPTION_KEY=.*|SECRET_ENCRYPTION_KEY=$SECRET_ENCRYPTION_KEY|" .env.docker
```

Make sure no placeholder values remain:

```bash
grep 'replace-' .env.docker
```

The expected result is no output.

> **Keep `.env.docker` private.** It contains database and application secrets. Do not post it in chat, screenshots, tickets, or Git commits.

## 7. Start Dorarion

```bash
sudo ./scripts/install-compose.sh
sudo docker compose --env-file .env.docker ps
```

If the services are running, continue to the administrator setup.

## 8. Generate the first Dorarion administrator password

Create the first local administrator with username `admin` and email `admin@example.com`:

```bash
cd ~/projects/dorarion-compose
sudo docker compose --env-file .env.docker run --rm dorarion \
  bootstrap-admin admin admin@example.com
```

Save the generated administrator password immediately in a password manager. You will use it on the login page.

| Field | Value |
| --- | --- |
| Username | `admin` |
| Email | `admin@example.com` |
| Password | The generated bootstrap administrator password |

## 9. Open Dorarion

On Windows, open Chrome, Edge, or another browser and go to:

<http://127.0.0.1:3000/login>

You can also try:

<http://localhost:3000/login>

Sign in with `admin` (or `admin@example.com`) and the generated administrator password from Step 8.

## 10. Useful checks

```bash
sudo docker compose --env-file .env.docker ps
sudo docker compose --env-file .env.docker logs --tail=100
```

If Dorarion is not opening, first confirm that the containers are `Up` and that port `3000` is published.

## Quick recap

- WSL 2 and Ubuntu installed.
- Docker Engine and Docker Compose installed.
- `dorarion-compose` cloned into `~/projects/dorarion-compose`.
- `.env.docker` secrets generated.
- Dorarion services started.
- First administrator generated with `bootstrap-admin`.
- Dorarion opened at <http://127.0.0.1:3000/login>.

## Official platform references

- [Install WSL](https://learn.microsoft.com/windows/wsl/install)
- [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
