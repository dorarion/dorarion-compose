# WSL 2 + Docker + Dorarion

간단한 로컬 설치 가이드

> **목표:** WSL 2에 Ubuntu를 설치하고, Docker를 설치한 다음, Dorarion을 복제하고 필요한 시크릿을 생성하며, 첫 번째 관리자 계정을 만든 뒤 Windows 브라우저에서 Dorarion을 엽니다.

- Windows 명령은 관리자 권한으로 실행한 PowerShell에서 실행합니다.
- Linux 및 Docker 명령은 Ubuntu WSL 터미널에서 실행합니다.
- 이 가이드는 로컬 컴퓨터에서 실제로 성공한 Dorarion Compose 설치 흐름을 따릅니다.
- [PDF 버전](pdf/dorarion-wsl-docker-install-ko.pdf)도 제공됩니다.

## 1. WSL 2 및 Ubuntu 설치

PowerShell을 관리자 권한으로 열고 다음을 실행합니다.

```powershell
wsl --install -d Ubuntu
```

요청되면 Windows를 다시 시작합니다. 그런 다음 시작 메뉴에서 Ubuntu를 열고 Linux 사용자 이름과 비밀번호를 만듭니다.

PowerShell에서 선택적으로 확인할 수 있습니다.

```powershell
wsl -l -v
```

Ubuntu의 `VERSION`이 `2`로 표시되어야 합니다.

## 2. Ubuntu 준비

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y git openssl ca-certificates curl
```

## 3. Docker Engine 및 Compose 설치

### 3.1 기존 또는 충돌하는 Docker 패키지 제거

```bash
sudo apt remove -y docker.io docker-compose docker-compose-v2 \
  docker-doc docker-buildx podman-docker containerd runc
```

### 3.2 Docker 공식 저장소 추가

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

### 3.3 Docker 설치 및 테스트

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo docker run --rm hello-world
docker --version
docker compose version
```

아래 명령은 Docker 실행 시 `sudo`를 사용합니다. 이 로컬 설치에서는 문제없으며 Docker 소켓 권한 문제를 피할 수 있습니다.

## 4. Dorarion 다운로드

```bash
mkdir -p ~/projects
cd ~/projects
git clone https://github.com/dorarion/dorarion-compose.git
cd dorarion-compose
```

## 5. Dorarion 준비

Dorarion의 Compose 설치 스크립트를 한 번 실행합니다. 이 스크립트는 `.env.docker`를 포함한 Compose 환경을 준비합니다.

```bash
./scripts/install-compose.sh
```

환경 파일을 확인합니다.

```bash
cat .env.docker
```

`.env.docker`의 소유자가 root이고 파일을 수정할 때 권한 오류가 발생하는 경우에만 다음을 실행합니다.

```bash
sudo chown "$USER:$USER" .env.docker
```

## 6. Dorarion 시크릿 생성

`dorarion-compose` 디렉터리에서 다음 명령을 실행합니다.

```bash
POSTGRES_PASSWORD="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 32)"
SECRET_ENCRYPTION_KEY="$(openssl rand -base64 32)"

sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env.docker
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env.docker
sed -i "s|^SECRET_ENCRYPTION_KEY=.*|SECRET_ENCRYPTION_KEY=$SECRET_ENCRYPTION_KEY|" .env.docker
```

placeholder 값이 남아 있지 않은지 확인합니다.

```bash
grep 'replace-' .env.docker
```

예상 결과는 아무 출력도 없는 것입니다.

> **`.env.docker`를 비공개로 유지하세요.** 이 파일에는 데이터베이스 및 애플리케이션 시크릿이 들어 있습니다. 채팅, 스크린샷, 티켓 또는 Git 커밋에 게시하지 마세요.

## 7. Dorarion 시작

```bash
sudo ./scripts/install-compose.sh
sudo docker compose --env-file .env.docker ps
```

서비스가 실행 중이면 관리자 설정으로 계속 진행합니다.

## 8. 첫 번째 Dorarion 관리자 비밀번호 생성

사용자 이름 `admin`, 이메일 `admin@example.com`으로 첫 번째 로컬 관리자를 생성합니다.

```bash
cd ~/projects/dorarion-compose
sudo docker compose --env-file .env.docker run --rm dorarion \
  bootstrap-admin admin admin@example.com
```

생성된 관리자 비밀번호를 즉시 비밀번호 관리자에 저장하세요. 로그인 페이지에서 이 값을 사용합니다.

| 항목 | 값 |
| --- | --- |
| 사용자 이름 | `admin` |
| 이메일 | `admin@example.com` |
| 비밀번호 | 생성된 bootstrap 관리자 비밀번호 |

## 9. Dorarion 열기

Windows에서 Chrome, Edge 또는 다른 브라우저를 열고 다음 주소로 이동합니다.

<http://127.0.0.1:3000/login>

다음 주소도 사용할 수 있습니다.

<http://localhost:3000/login>

`admin`(또는 `admin@example.com`)과 8단계에서 생성한 관리자 비밀번호로 로그인합니다.

## 10. 유용한 확인 명령

```bash
sudo docker compose --env-file .env.docker ps
sudo docker compose --env-file .env.docker logs --tail=100
```

Dorarion이 열리지 않으면 먼저 컨테이너 상태가 `Up`인지, 그리고 포트 `3000`이 공개되어 있는지 확인합니다.

## 빠른 요약

- WSL 2 및 Ubuntu 설치 완료.
- Docker Engine 및 Docker Compose 설치 완료.
- `dorarion-compose`를 `~/projects/dorarion-compose`에 복제 완료.
- `.env.docker` 시크릿 생성 완료.
- Dorarion 서비스 시작 완료.
- `bootstrap-admin`으로 첫 번째 관리자 생성 완료.
- <http://127.0.0.1:3000/login>에서 Dorarion 열기 완료.

## 공식 플랫폼 참고 자료

- [Microsoft WSL 설치](https://learn.microsoft.com/windows/wsl/install)
- [Ubuntu용 Docker Engine 설치](https://docs.docker.com/engine/install/ubuntu/)
