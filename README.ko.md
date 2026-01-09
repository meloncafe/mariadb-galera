# MariaDB Galera Cluster

[![Docker Pulls](https://img.shields.io/docker/pulls/devsaurus/mariadb-galera)](https://hub.docker.com/r/devsaurus/mariadb-galera)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

공식 MariaDB 이미지에 Galera 클러스터 자동화 스크립트를 추가한 이미지입니다.

[English](README.md)

## 개요

공식 `mariadb` Docker 이미지를 확장하여 다음 기능을 제공합니다:
- Galera 클러스터 자동 설정
- 부트스트랩 감지 및 처리
- SST 사용자 관리
- 클러스터 상태 헬스체크

**소스 컴파일 없음** - 공식 MariaDB 바이너리를 사용하여 안정성과 빠른 빌드를 보장합니다.

## 빠른 시작

### 단일 노드 (테스트용)

```bash
docker run -d --name galera \
  -e MARIADB_ROOT_PASSWORD=secret \
  -e GALERA_CLUSTER_BOOTSTRAP=yes \
  devsaurus/mariadb-galera:11.4
```

### 3노드 클러스터

```bash
# 1. 부트스트랩 노드 시작
docker run -d --name galera-1 \
  -e MARIADB_ROOT_PASSWORD=secret \
  -e GALERA_CLUSTER_NAME=mycluster \
  -e GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3 \
  -e GALERA_CLUSTER_BOOTSTRAP=yes \
  -e GALERA_SST_PASSWORD=sstpass \
  devsaurus/mariadb-galera:11.4

# 2. 부트스트랩 완료 후 나머지 노드 시작
docker run -d --name galera-2 \
  -e MARIADB_ROOT_PASSWORD=secret \
  -e GALERA_CLUSTER_NAME=mycluster \
  -e GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3 \
  -e GALERA_SST_PASSWORD=sstpass \
  devsaurus/mariadb-galera:11.4
```

### Docker Compose

[docker-compose.yml](docker-compose.yml)에서 완전한 3노드 클러스터 예제를 확인하세요.

## 환경 변수

### MariaDB (공식)

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `MARIADB_ROOT_PASSWORD` | Root 비밀번호 (필수) | - |
| `MARIADB_DATABASE` | 시작 시 생성할 데이터베이스 | - |
| `MARIADB_USER` | 시작 시 생성할 사용자 | - |
| `MARIADB_PASSWORD` | MARIADB_USER 비밀번호 | - |

### Galera (Devsaurus)

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `GALERA_CLUSTER_NAME` | 클러스터 이름 | `galera_cluster` |
| `GALERA_CLUSTER_ADDRESS` | 노드 목록 (쉼표 구분) | - |
| `GALERA_CLUSTER_BOOTSTRAP` | 새 클러스터 부트스트랩 | `no` |
| `GALERA_NODE_NAME` | 이 노드의 이름 | `$(hostname)` |
| `GALERA_NODE_ADDRESS` | 이 노드의 IP | 자동 감지 |
| `GALERA_SST_METHOD` | SST 방식 | `mariabackup` |
| `GALERA_SST_USER` | SST 사용자 | `mariabackup` |
| `GALERA_SST_PASSWORD` | SST 비밀번호 | - |
| `GALERA_FORCE_BOOTSTRAP` | 강제 부트스트랩 (복구용) | `no` |

## 포트

| 포트 | 프로토콜 | 설명 |
|------|----------|------|
| 3306 | TCP | MySQL 클라이언트 |
| 4567 | TCP/UDP | Galera 복제 |
| 4568 | TCP | IST (증분 상태 전송) |
| 4444 | TCP | SST (상태 스냅샷 전송) |

## 볼륨

| 경로 | 설명 |
|------|------|
| `/var/lib/mysql` | 데이터베이스 데이터 |
| `/docker-entrypoint-initdb.d` | 초기화 스크립트 (`.sh`, `.sql`, `.sql.gz`, `.sql.xz`, `.sql.zst`) |

## 부트스트랩 로직

엔트리포인트가 자동으로 부트스트랩 여부를 결정합니다:

1. `GALERA_CLUSTER_BOOTSTRAP=yes` → 부트스트랩
2. `GALERA_FORCE_BOOTSTRAP=yes` → 강제 부트스트랩 (복구)
3. 데이터 없음 + 다른 노드 접근 불가 → 부트스트랩
4. `safe_to_bootstrap: 1` + 다른 노드 없음 → 부트스트랩
5. 그 외 → 기존 클러스터에 조인

## 아키텍처

```
┌─────────────────────────────────────────────────┐
│ devsaurus/mariadb-galera                        │
├─────────────────────────────────────────────────┤
│ /opt/devsaurus/                                 │
│   ├── bin/entrypoint.sh    (Galera 자동화)     │
│   ├── bin/healthcheck.sh   (클러스터 헬스체크) │
│   └── lib/common.sh        (공통 함수)         │
├─────────────────────────────────────────────────┤
│ 공식 mariadb:xx 이미지                          │
│   └── /usr/local/bin/docker-entrypoint.sh      │
└─────────────────────────────────────────────────┘
```

## 라이선스

- **스크립트** (`/opt/devsaurus/`): MIT 라이선스
- **MariaDB**: GPLv2 (공식 이미지)

## 링크

- [Docker Hub](https://hub.docker.com/r/devsaurus/mariadb-galera)
- [GitHub](https://github.com/meloncafe/mariadb-galera)
- [공식 MariaDB 이미지](https://hub.docker.com/_/mariadb)
- [Galera 문서](https://galeracluster.com/library/documentation/)
