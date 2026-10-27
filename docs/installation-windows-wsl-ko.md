# WSL 2 + Docker + Dorarion

> 베타 DB 안내 (2026-10-10): 현재 core는 두 개의 통합 마이그레이션으로 설치합니다. 이전 베타 DB는 새 빈 DB를 쓰거나 기존 데이터를 삭제하고 명시적으로 재설치해야 합니다. SQLx 이력만 삭제하지 마세요. 현재 소스로 새 이미지를 빌드하세요. 최신 정책은 README를 확인하세요. 이전에 다운로드한 PDF에는 과거 마이그레이션 절차가 남아 있을 수 있습니다.

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
cp .env.docker.example .env.docker
chmod 600 .env.docker
${EDITOR:-nano} .env.docker
```

환경 파일을 확인합니다.

```bash
${EDITOR:-nano} .env.docker
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
chmod 600 .env.docker

sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|" .env.docker
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" .env.docker
sed -i "s|^SECRET_ENCRYPTION_KEY=.*|SECRET_ENCRYPTION_KEY=$SECRET_ENCRYPTION_KEY|" .env.docker
unset POSTGRES_PASSWORD JWT_SECRET SECRET_ENCRYPTION_KEY
```

placeholder 값이 남아 있지 않은지 확인합니다.

```bash
if grep -q 'replace-' .env.docker; then echo 'Replace remaining image/credential placeholders'; fi
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

## 설치와 업그레이드 — reviewed core

이 설정은 검토된 1.0 이전 core 소스를 기준으로 합니다. 해당 소스로 빌드한 이미지를 선택하세요. 기존 이전 레지스트리 태그만으로 보안 개선 포함 여부를 확인할 수 없습니다.

1.0 이전 버전입니다. 선택한 이미지의 API 계약을 기준으로 연동하세요. 검토된 소스는 CI/CD, 운영 작업, 장애 및 일간·주간 활동 보고를 지원합니다.

- `JWT_SECRET`(32바이트 이상)과 `SECRET_ENCRYPTION_KEY`(무작위 32바이트의 Base64)를 한 번 생성하고 Git 밖에 보관하세요.
- API 풀 기본값은 15개입니다. 복제본마다 워커 연결 6개와 임시 마이그레이션 연결도 확보하세요.
- Compose는 내부 `postgres` 호스트만 명시적으로 신뢰합니다. 외부 PostgreSQL은 `sslmode=verify-full`과 신뢰할 CA가 필요합니다.
- 외부 자격 증명은 `env://DORARION_EXT_<NAME>`을 사용합니다. core 비밀 환경 변수는 항상 차단됩니다.
- Argo CD는 애플리케이션별 회전 토큰과 활성 애플리케이션·연동이 필요합니다. 장애 자동화는 저장소 범위가 지정된 incident source를 사용합니다.

`/health/live`는 프로세스, `/health/ready`는 PostgreSQL을 확인합니다. 워커 상태는 인증이 필요한 `/health/workers`에서 따로 확인합니다. Prometheus에는 Secret에 보관한 ASCII 32–512자 `DORARION_METRICS_SCRAPE_TOKEN`을 사용하고 `/metrics`에만 전달하세요. 전달된 클라이언트 주소를 신뢰하기 전에 프록시 네트워크를 명시하세요.

전진 마이그레이션 전에 PostgreSQL과 정확한 암호화 키를 백업하세요. 마이그레이션 Job 또는 서비스를 한 번 실행하고 서버 시작 시 마이그레이션은 끕니다. 첫 로그인에서 생성된 관리자 비밀번호를 변경하고 업그레이드 후 Argo 애플리케이션 토큰을 회전하세요. 감사 보존 기간은 365일보다 짧을 수 없습니다. 주간 보고는 발송 전 완료된 현지 날짜 7일이며 수동 발송 재시도에는 같은 Idempotency-Key를 사용합니다. 장애 재개는 명시해야 합니다. 데모 경로는 제거되었고 알 수 없는 요청 필드는 거부되므로 이미지에 포함된 API 계약을 확인하세요. 운영 배포 전에 백업 복원, 공급자 전송과 readiness를 검증하세요.

Compose: select `DORARION_IMAGE` before starting. Local HTTP uses `DORARION_COOKIE_SECURE=false`; set a reachable HTTPS public origin and secure cookies for remote use. The published port binds to `127.0.0.1` by default. `/health/ready` is database-only; the container uses the native `dorarion-core healthcheck` command. `DORARION_MIGRATE_ON_START=false` delegates migration to the one-shot service. The environment file is private (0600); avoid printing it.


## 릴리스 및 복원 주의사항 (2026-10-27)

릴리스 태그를 덮어쓰지 마세요. 이 배포 설정은 코어 `0.0.8`을 사용합니다.
기존 `.env.docker`의 `DORARION_IMAGE`를
`docker.io/kimc1992/dorarion-core:0.0.8@sha256:156e422514c7974010483a8938c579453d02f884353b9b4b9b9919537fed9f97`로
변경하세요. 공유 이미지 인덱스입니다. 지원 플랫폼은 README에서 확인하세요. Docker가 호스트에 맞는 이미지를 선택합니다.
이전 digest를 포함한 이미지 값 전체를 교체하세요.
`/health`와 `/api/openapi.json`의 버전이 모두 `0.0.8`인지 확인하세요.

제공자 연결에는 `DORARION_ALLOWED_PRIVATE_PROVIDER_HOSTS=gitlab.corp.example`,
웹훅에는 `DORARION_ALLOWED_PRIVATE_WEBHOOK_HOSTS=hooks.corp.example`를 사용하세요.
쉼표로 구분한 정확한 호스트명, IP 주소 또는 CIDR만 허용합니다. URL 스킴,
일반 경로, `gitlab.corp.example:8443` 같은 호스트명과 포트 조합은 넣지 마세요.
제공자 URL 자체에는 포트를 지정할 수 있습니다. 기존 전체 허용 스위치는 폐기 예정입니다.

앱과 receiver의 쓰기를 멈추고 백업은 반드시 **새 빈 데이터베이스**에 복원하세요.
기존 DB와 암호화 키를 보존하세요. `pg_restore --clean --if-exists`로 이전 백업을
새 버전 DB에 덮어쓰면 백업에 없는 신규 객체가 남아 다음 마이그레이션이 실패할 수 있습니다.
복원한 DB로 연결을 변경하고 마이그레이션과 readiness 확인 후 트래픽을 재개하세요.
