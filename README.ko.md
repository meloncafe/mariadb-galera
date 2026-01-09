# MariaDB Galera Cluster

[![Build](https://github.com/meloncafe/mariadb-galera/actions/workflows/build.yml/badge.svg)](https://github.com/meloncafe/mariadb-galera/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Pulls](https://img.shields.io/docker/pulls/devsaurus/mariadb-galera)](https://hub.docker.com/r/devsaurus/mariadb-galera)

**[English](README.md)**

소스 코드에서 직접 빌드한 MariaDB Galera Cluster Docker 이미지입니다.

## 🎯 프로젝트 특징

- **100% 오픈소스**: 스크립트는 MIT 라이선스, 바이너리는 GPL 소스에서 빌드
- **서드파티 바이너리 의존성 없음**: 모든 것을 공식 소스 코드에서 직접 컴파일
- **투명한 빌드 프로세스**: Multi-stage Dockerfile, 완전히 감사 가능
- **멀티 아키텍처 지원**: `linux/amd64` 및 `linux/arm64`

## 📦 빠른 시작

### 단일 노드 (개발용)

```bash
docker run -d --name galera \
  -e MARIADB_ROOT_PASSWORD=my_root_password \
  -e GALERA_SST_PASSWORD=my_sst_password \
  -e GALERA_CLUSTER_BOOTSTRAP=yes \
  -p 3306:3306 \
  devsaurus/mariadb-galera:latest
```

### 3노드 클러스터

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  galera-1:
    image: devsaurus/mariadb-galera:latest
    environment:
      - MARIADB_ROOT_PASSWORD=my_root_password
      - GALERA_SST_PASSWORD=my_sst_password
      - GALERA_CLUSTER_NAME=my_cluster
      - GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3
      - GALERA_CLUSTER_BOOTSTRAP=yes
      - GALERA_NODE_NAME=galera-1
    volumes:
      - galera-1-data:/var/lib/mysql
    networks:
      - galera-net

  galera-2:
    image: devsaurus/mariadb-galera:latest
    environment:
      - MARIADB_ROOT_PASSWORD=my_root_password
      - GALERA_SST_PASSWORD=my_sst_password
      - GALERA_CLUSTER_NAME=my_cluster
      - GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3
      - GALERA_NODE_NAME=galera-2
    volumes:
      - galera-2-data:/var/lib/mysql
    networks:
      - galera-net
    depends_on:
      - galera-1

  galera-3:
    image: devsaurus/mariadb-galera:latest
    environment:
      - MARIADB_ROOT_PASSWORD=my_root_password
      - GALERA_SST_PASSWORD=my_sst_password
      - GALERA_CLUSTER_NAME=my_cluster
      - GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3
      - GALERA_NODE_NAME=galera-3
    volumes:
      - galera-3-data:/var/lib/mysql
    networks:
      - galera-net
    depends_on:
      - galera-1

volumes:
  galera-1-data:
  galera-2-data:
  galera-3-data:

networks:
  galera-net:
    driver: bridge
```

**클러스터 시작:**

```bash
# 부트스트랩 노드 먼저 시작
docker-compose up -d galera-1

# 준비될 때까지 대기
docker-compose exec galera-1 /usr/local/bin/healthcheck.sh

# 나머지 노드 시작
docker-compose up -d galera-2 galera-3
```

## ⚙️ 환경 변수

### MariaDB 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `MARIADB_ROOT_PASSWORD` | (필수) | Root 사용자 비밀번호 |
| `MARIADB_ROOT_HOST` | `%` | Root 사용자 호스트 패턴 |
| `MARIADB_USER` | | 애플리케이션 데이터베이스 사용자 |
| `MARIADB_PASSWORD` | | 애플리케이션 사용자 비밀번호 |
| `MARIADB_DATABASE` | | 애플리케이션 데이터베이스 이름 |
| `MARIADB_PORT` | `3306` | MariaDB 포트 |
| `MARIADB_BIND_ADDRESS` | `0.0.0.0` | 바인드 주소 |
| `MARIADB_CHARACTER_SET` | `utf8mb4` | 기본 문자셋 |
| `ALLOW_EMPTY_PASSWORD` | `no` | 빈 root 비밀번호 허용 |

### Galera 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `GALERA_CLUSTER_NAME` | `galera_cluster` | 클러스터 이름 |
| `GALERA_CLUSTER_ADDRESS` | | 클러스터 노드 목록 (쉼표 구분) |
| `GALERA_CLUSTER_BOOTSTRAP` | `no` | 새 클러스터 부트스트랩 (`yes`/`no`) |
| `GALERA_NODE_NAME` | `$(hostname)` | 현재 노드 이름 |
| `GALERA_NODE_ADDRESS` | 자동 감지 | 현재 노드 IP 주소 |
| `GALERA_SST_METHOD` | `mariabackup` | SST 방식 (`mariabackup`/`rsync`/`mysqldump`) |
| `GALERA_SST_USER` | `mariabackup` | SST 인증 사용자 |
| `GALERA_SST_PASSWORD` | (클러스터 시 필수) | SST 인증 비밀번호 |
| `GALERA_FORCE_BOOTSTRAP` | `no` | 강제 부트스트랩 (복구용) |

## 📂 볼륨

| 경로 | 설명 |
|------|------|
| `/var/lib/mysql` | 데이터베이스 데이터 디렉토리 |
| `/docker-entrypoint-initdb.d` | 초기화 스크립트 (`.sh`, `.sql`, `.sql.gz`, `.sql.xz`, `.sql.zst`) |
| `/etc/mysql/conf.d` | 사용자 정의 설정 파일 |

## 🔌 포트

| 포트 | 프로토콜 | 설명 |
|------|----------|------|
| 3306 | TCP | MariaDB 클라이언트 연결 |
| 4444 | TCP | SST (State Snapshot Transfer) |
| 4567 | TCP/UDP | Galera 클러스터 복제 |
| 4568 | TCP | IST (Incremental State Transfer) |

## 🏥 헬스 체크

이미지에는 다음을 확인하는 내장 헬스 체크가 포함되어 있습니다:

1. MariaDB 실행 중
2. wsrep 준비됨 (`wsrep_ready = ON`)
3. Primary 클러스터 상태 (`wsrep_cluster_status = Primary`)
4. 노드 동기화됨 (`wsrep_local_state_comment = Synced`)

수동 확인:

```bash
docker exec <container> /usr/local/bin/healthcheck.sh
```

## 🔧 소스에서 빌드

```bash
git clone https://github.com/meloncafe/mariadb-galera.git
cd mariadb-galera

# 기본 버전으로 빌드
docker build -t mariadb-galera .

# 특정 버전으로 빌드
docker build \
  --build-arg MARIADB_VERSION=12.1.2 \
  --build-arg GALERA_VERSION=26.4.21 \
  -t mariadb-galera .
```

## 📜 라이선스

### 스크립트 및 설정 (이 저장소)

**MIT 라이선스** - [LICENSE](LICENSE) 참조

스크립트 및 설정 파일을 자유롭게 사용, 수정, 배포할 수 있습니다.

### 포함된 바이너리

Docker 이미지에는 소스에서 빌드된 바이너리가 포함되어 있으며, 각각의 라이선스가 적용됩니다:

| 컴포넌트 | 라이선스 | 소스 |
|----------|----------|------|
| MariaDB Server | GPLv2 | [MariaDB Archive](https://archive.mariadb.org/) |
| Galera Provider | GPLv2 | [GitHub](https://github.com/codership/galera) |

이 이미지나 파생물을 배포할 때는 GPL 요구사항(소스 코드 가용성)을 준수해야 합니다.

## 🤝 기여

기여를 환영합니다! 이슈와 풀 리퀘스트를 자유롭게 제출해 주세요.

## 📚 참고 자료

- [MariaDB Galera Cluster 문서](https://mariadb.com/kb/en/galera-cluster/)
- [Galera Cluster 문서](https://galeracluster.com/library/documentation/)
- [MariaDB 소스 빌드 가이드](https://mariadb.com/kb/en/compiling-mariadb-from-source/)

## ⚠️ 면책 조항

이 프로젝트는 MariaDB Corporation, Codership Oy 또는 그 계열사와 관련이 없습니다. MariaDB와 Galera는 각 소유자의 상표입니다.
