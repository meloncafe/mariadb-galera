# MariaDB Galera Cluster

[![Build](https://github.com/meloncafe/mariadb-galera/actions/workflows/build.yml/badge.svg)](https://github.com/meloncafe/mariadb-galera/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Pulls](https://img.shields.io/docker/pulls/devsaurus/mariadb-galera)](https://hub.docker.com/r/devsaurus/mariadb-galera)

**[한국어 README](README.ko.md)**

A **clean-room implementation** of MariaDB Galera Cluster Docker image, built entirely from source code.

## 🎯 Why This Project?

- **100% Open Source**: Scripts are MIT licensed, binaries built from GPL source
- **No Third-Party Binary Dependencies**: Everything compiled from official source code
- **Transparent Build Process**: Multi-stage Dockerfile, fully auditable
- **Multi-Architecture**: Supports both `linux/amd64` and `linux/arm64`

## 📦 Quick Start

### Single Node (Development)

```bash
docker run -d --name galera \
  -e MARIADB_ROOT_PASSWORD=my_root_password \
  -e GALERA_SST_PASSWORD=my_sst_password \
  -e GALERA_CLUSTER_BOOTSTRAP=yes \
  -p 3306:3306 \
  devsaurus/mariadb-galera:latest
```

### Three-Node Cluster

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

**Start the cluster:**

```bash
# Start bootstrap node first
docker-compose up -d galera-1

# Wait for it to be ready
docker-compose exec galera-1 /usr/local/bin/healthcheck.sh

# Start remaining nodes
docker-compose up -d galera-2 galera-3
```

## ⚙️ Environment Variables

### MariaDB Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MARIADB_ROOT_PASSWORD` | (required) | Root user password |
| `MARIADB_ROOT_HOST` | `%` | Host pattern for root user |
| `MARIADB_USER` | | Application database user |
| `MARIADB_PASSWORD` | | Application user password |
| `MARIADB_DATABASE` | | Application database name |
| `MARIADB_PORT` | `3306` | MariaDB port |
| `MARIADB_BIND_ADDRESS` | `0.0.0.0` | Bind address |
| `MARIADB_CHARACTER_SET` | `utf8mb4` | Default character set |
| `ALLOW_EMPTY_PASSWORD` | `no` | Allow empty root password |

### Galera Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GALERA_CLUSTER_NAME` | `galera_cluster` | Cluster name |
| `GALERA_CLUSTER_ADDRESS` | | Comma-separated list of cluster nodes |
| `GALERA_CLUSTER_BOOTSTRAP` | `no` | Bootstrap new cluster (`yes`/`no`) |
| `GALERA_NODE_NAME` | `$(hostname)` | This node's name |
| `GALERA_NODE_ADDRESS` | auto-detected | This node's IP address |
| `GALERA_SST_METHOD` | `mariabackup` | SST method (`mariabackup`/`rsync`/`mysqldump`) |
| `GALERA_SST_USER` | `mariabackup` | SST authentication user |
| `GALERA_SST_PASSWORD` | (required for cluster) | SST authentication password |
| `GALERA_FORCE_BOOTSTRAP` | `no` | Force bootstrap (recovery) |

## 📂 Volumes

| Path | Description |
|------|-------------|
| `/var/lib/mysql` | Database data directory |
| `/docker-entrypoint-initdb.d` | Initialization scripts (`.sh`, `.sql`) |
| `/etc/mysql/conf.d` | Custom configuration files |

## 🔌 Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3306 | TCP | MariaDB client connections |
| 4444 | TCP | SST (State Snapshot Transfer) |
| 4567 | TCP/UDP | Galera cluster replication |
| 4568 | TCP | IST (Incremental State Transfer) |

## 🏥 Health Check

The image includes a built-in health check that verifies:

1. MariaDB is running
2. wsrep is ready (`wsrep_ready = ON`)
3. Node is in Primary cluster (`wsrep_cluster_status = Primary`)
4. Node is synced (`wsrep_local_state_comment = Synced`)

Manual check:

```bash
docker exec <container> /usr/local/bin/healthcheck.sh
```

## 🔧 Building from Source

```bash
git clone https://github.com/meloncafe/mariadb-galera.git
cd mariadb-galera

# Build with default versions
docker build -t mariadb-galera .

# Build with specific versions
docker build \
  --build-arg MARIADB_VERSION=12.1.2 \
  --build-arg GALERA_VERSION=26.4.21 \
  -t mariadb-galera .
```

## 📜 License

### Scripts & Configuration (This Repository)

**MIT License** - See [LICENSE](LICENSE)

You are free to use, modify, and distribute the scripts and configuration files.

### Bundled Binaries

The Docker image contains binaries built from source, licensed under their respective licenses:

| Component | License | Source |
|-----------|---------|--------|
| MariaDB Server | GPLv2 | [MariaDB Archive](https://archive.mariadb.org/) |
| Galera Provider | GPLv2 | [GitHub](https://github.com/codership/galera) |

When distributing this image or derivatives, you must comply with GPL requirements (source code availability).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📚 References

- [MariaDB Galera Cluster Documentation](https://mariadb.com/kb/en/galera-cluster/)
- [Galera Cluster Documentation](https://galeracluster.com/library/documentation/)
- [MariaDB Source Build Guide](https://mariadb.com/kb/en/compiling-mariadb-from-source/)

## ⚠️ Disclaimer

This project is not affiliated with MariaDB Corporation, Codership Oy, or any of their affiliates. MariaDB and Galera are trademarks of their respective owners.
