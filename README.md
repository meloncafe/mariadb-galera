# MariaDB Galera Cluster

[![Docker Pulls](https://img.shields.io/docker/pulls/devsaurus/mariadb-galera)](https://hub.docker.com/r/devsaurus/mariadb-galera)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Official MariaDB image with Galera cluster automation scripts.

[한국어](README.ko.md)

## Overview

This image extends the official `mariadb` Docker image with:
- Automatic Galera cluster configuration
- Bootstrap detection and handling
- SST user management
- Health checks for cluster status

**No source compilation** - Uses official MariaDB binaries for reliability and fast builds.

## Quick Start

### Single Node (Testing)

```bash
docker run -d --name galera \
  -e MARIADB_ROOT_PASSWORD=secret \
  -e GALERA_CLUSTER_BOOTSTRAP=yes \
  devsaurus/mariadb-galera:11.4
```

### 3-Node Cluster

```bash
# 1. Start bootstrap node
docker run -d --name galera-1 \
  -e MARIADB_ROOT_PASSWORD=secret \
  -e GALERA_CLUSTER_NAME=mycluster \
  -e GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3 \
  -e GALERA_CLUSTER_BOOTSTRAP=yes \
  -e GALERA_SST_PASSWORD=sstpass \
  devsaurus/mariadb-galera:11.4

# 2. Wait for bootstrap to complete, then start other nodes
docker run -d --name galera-2 \
  -e MARIADB_ROOT_PASSWORD=secret \
  -e GALERA_CLUSTER_NAME=mycluster \
  -e GALERA_CLUSTER_ADDRESS=galera-1,galera-2,galera-3 \
  -e GALERA_SST_PASSWORD=sstpass \
  devsaurus/mariadb-galera:11.4
```

### Docker Compose

See [docker-compose.yml](docker-compose.yml) for a complete 3-node cluster example.

## Environment Variables

### MariaDB (Official)

| Variable | Description | Default |
|----------|-------------|---------|
| `MARIADB_ROOT_PASSWORD` | Root password (required) | - |
| `MARIADB_DATABASE` | Create database on startup | - |
| `MARIADB_USER` | Create user on startup | - |
| `MARIADB_PASSWORD` | Password for MARIADB_USER | - |

### Galera (Devsaurus)

| Variable | Description | Default |
|----------|-------------|---------|
| `GALERA_CLUSTER_NAME` | Cluster name | `galera_cluster` |
| `GALERA_CLUSTER_ADDRESS` | Comma-separated node list | - |
| `GALERA_CLUSTER_BOOTSTRAP` | Bootstrap new cluster | `no` |
| `GALERA_NODE_NAME` | This node's name | `$(hostname)` |
| `GALERA_NODE_ADDRESS` | This node's IP | auto-detected |
| `GALERA_SST_METHOD` | SST method | `mariabackup` |
| `GALERA_SST_USER` | SST user | `mariabackup` |
| `GALERA_SST_PASSWORD` | SST password | - |
| `GALERA_FORCE_BOOTSTRAP` | Force bootstrap (recovery) | `no` |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3306 | TCP | MySQL client |
| 4567 | TCP/UDP | Galera replication |
| 4568 | TCP | IST (Incremental State Transfer) |
| 4444 | TCP | SST (State Snapshot Transfer) |

## Volumes

| Path | Description |
|------|-------------|
| `/var/lib/mysql` | Database data |
| `/docker-entrypoint-initdb.d` | Init scripts (`.sh`, `.sql`, `.sql.gz`, `.sql.xz`, `.sql.zst`) |

## Bootstrap Logic

The entrypoint automatically determines whether to bootstrap:

1. `GALERA_CLUSTER_BOOTSTRAP=yes` → Bootstrap
2. `GALERA_FORCE_BOOTSTRAP=yes` → Force bootstrap (recovery)
3. No data + no other nodes reachable → Bootstrap
4. `safe_to_bootstrap: 1` + no other nodes → Bootstrap
5. Otherwise → Join existing cluster

## Architecture

```
┌─────────────────────────────────────────────────┐
│ devsaurus/mariadb-galera                        │
├─────────────────────────────────────────────────┤
│ /opt/devsaurus/                                 │
│   ├── bin/entrypoint.sh    (Galera automation)  │
│   ├── bin/healthcheck.sh   (Cluster health)     │
│   └── lib/common.sh        (Shared functions)   │
├─────────────────────────────────────────────────┤
│ Official mariadb:xx image                       │
│   └── /usr/local/bin/docker-entrypoint.sh       │
└─────────────────────────────────────────────────┘
```

## License

- **Scripts** (`/opt/devsaurus/`): MIT License
- **MariaDB**: GPLv2 (official image)

## Links

- [Docker Hub](https://hub.docker.com/r/devsaurus/mariadb-galera)
- [GitHub](https://github.com/meloncafe/mariadb-galera)
- [Official MariaDB Image](https://hub.docker.com/_/mariadb)
- [Galera Documentation](https://galeracluster.com/library/documentation/)
