# MariaDB Galera Cluster - Built from Source
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 devsaurus
#
# This Dockerfile builds MariaDB and Galera from source.
# The resulting binaries are licensed under GPLv2.
# Scripts and configuration are MIT licensed.

ARG MARIADB_VERSION=12.1.2
ARG GALERA_VERSION=26.4.21
ARG DEBIAN_VERSION=bookworm

# =============================================================================
# Stage 1: Build MariaDB from Source
# =============================================================================
FROM debian:${DEBIAN_VERSION} AS mariadb-builder

ARG MARIADB_VERSION
ARG TARGETARCH

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    git \
    curl \
    ca-certificates \
    bison \
    libncurses5-dev \
    libssl-dev \
    libaio-dev \
    libsystemd-dev \
    libpam0g-dev \
    libboost-dev \
    libboost-program-options-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    liblz4-dev \
    libzstd-dev \
    libjemalloc-dev \
    libsnappy-dev \
    libbz2-dev \
    gnutls-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Download MariaDB source
RUN curl -SsL "https://archive.mariadb.org/mariadb-${MARIADB_VERSION}/source/mariadb-${MARIADB_VERSION}.tar.gz" \
    | tar xz --strip-components=1

# Configure and build MariaDB with Galera support
RUN cmake . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
    -DMYSQL_DATADIR=/var/lib/mysql \
    -DSYSCONFDIR=/etc/mysql \
    -DMYSQL_UNIX_ADDR=/var/run/mysqld/mysqld.sock \
    -DWITH_WSREP=ON \
    -DWITH_INNODB_DISALLOW_WRITES=ON \
    -DWITH_SSL=system \
    -DWITH_ZLIB=system \
    -DWITH_JEMALLOC=yes \
    -DPLUGIN_TOKUDB=NO \
    -DPLUGIN_MROONGA=NO \
    -DPLUGIN_SPIDER=NO \
    -DPLUGIN_OQGRAPH=NO \
    -DPLUGIN_PERFSCHEMA=YES \
    -DPLUGIN_SPHINX=NO \
    -DWITH_EMBEDDED_SERVER=OFF \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_MARIABACKUP=ON \
    -DCONC_WITH_SSL=ON

# Build with parallel jobs
RUN make -j$(nproc)

# Install to staging directory
RUN make install DESTDIR=/mariadb-install

# =============================================================================
# Stage 2: Build Galera from Source
# =============================================================================
FROM debian:${DEBIAN_VERSION} AS galera-builder

ARG GALERA_VERSION

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    scons \
    pkg-config \
    git \
    ca-certificates \
    libboost-dev \
    libboost-program-options-dev \
    libssl-dev \
    check \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone Galera repository
RUN git clone --depth 1 --branch "release_${GALERA_VERSION}" \
    https://github.com/codership/galera.git .

# Initialize submodules
RUN git submodule init && git submodule update

# Build Galera
RUN scons -j$(nproc)

# Copy built library
RUN mkdir -p /galera-install/usr/lib/galera && \
    cp libgalera_smm.so /galera-install/usr/lib/galera/ && \
    cp garb/garbd /galera-install/usr/lib/galera/

# =============================================================================
# Stage 3: Runtime Image
# =============================================================================
FROM debian:${DEBIAN_VERSION}-slim AS runtime

ARG MARIADB_VERSION
ARG GALERA_VERSION

LABEL org.opencontainers.image.title="MariaDB Galera Cluster" \
      org.opencontainers.image.description="MariaDB Galera Cluster built from source - MIT licensed scripts" \
      org.opencontainers.image.version="${MARIADB_VERSION}" \
      org.opencontainers.image.vendor="devsaurus" \
      org.opencontainers.image.licenses="MIT AND GPL-2.0-only" \
      org.opencontainers.image.source="https://github.com/meloncafe/mariadb-galera"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libaio1 \
    libncurses6 \
    libssl3 \
    libpam0g \
    libjemalloc2 \
    libcurl4 \
    libxml2 \
    liblz4-1 \
    libzstd1 \
    libsnappy1v5 \
    libbz2-1.0 \
    libgnutls30 \
    libboost-program-options1.74.0 \
    socat \
    rsync \
    lsof \
    iproute2 \
    procps \
    netcat-openbsd \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create mysql user and group
RUN groupadd -r mysql && useradd -r -g mysql mysql

# Copy MariaDB from builder
COPY --from=mariadb-builder /mariadb-install/usr/local/mysql /usr/local/mysql

# Copy Galera from builder
COPY --from=galera-builder /galera-install/usr/lib/galera /usr/lib/galera

# Create directories
RUN mkdir -p \
    /var/lib/mysql \
    /var/log/mysql \
    /var/run/mysqld \
    /etc/mysql/conf.d \
    /docker-entrypoint-initdb.d \
    && chown -R mysql:mysql \
        /var/lib/mysql \
        /var/log/mysql \
        /var/run/mysqld \
    && chmod 750 /var/lib/mysql

# Copy scripts
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Add MariaDB binaries to PATH
ENV PATH="/usr/local/mysql/bin:/usr/local/mysql/scripts:${PATH}"
ENV MARIADB_BASE_DIR="/usr/local/mysql"
ENV GALERA_PROVIDER="/usr/lib/galera/libgalera_smm.so"

# Expose ports
# 3306 - MariaDB
# 4444 - SST (State Snapshot Transfer)
# 4567 - Galera Cluster (gcomm)
# 4568 - IST (Incremental State Transfer)
EXPOSE 3306 4444 4567 4568

# Volume for data persistence
VOLUME ["/var/lib/mysql"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

# Run as mysql user
USER mysql

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
