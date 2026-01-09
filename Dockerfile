# MariaDB Galera Cluster
# Based on official MariaDB image with devsaurus automation scripts
# SPDX-License-Identifier: MIT

ARG MARIADB_VERSION=11.4

FROM mariadb:${MARIADB_VERSION}

LABEL org.opencontainers.image.title="MariaDB Galera Cluster" \
      org.opencontainers.image.description="Official MariaDB with Galera cluster automation" \
      org.opencontainers.image.vendor="Devsaurus" \
      org.opencontainers.image.source="https://github.com/meloncafe/mariadb-galera" \
      org.opencontainers.image.licenses="MIT"

# Install additional utilities for cluster management
RUN apt-get update && apt-get install -y --no-install-recommends \
        netcat-openbsd \
        iproute2 \
        procps \
    && rm -rf /var/lib/apt/lists/*

# Copy Devsaurus scripts
COPY scripts/lib/ /opt/devsaurus/lib/
COPY scripts/bin/ /opt/devsaurus/bin/

RUN chmod +x /opt/devsaurus/bin/*.sh

# Environment
ENV PATH="/opt/devsaurus/bin:$PATH"

# Galera ports
# 3306  - MySQL client connections
# 4567  - Galera cluster replication (TCP + UDP)
# 4568  - IST (Incremental State Transfer)
# 4444  - SST (State Snapshot Transfer)
EXPOSE 3306 4567 4567/udp 4568 4444

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/devsaurus/bin/healthcheck.sh

ENTRYPOINT ["/opt/devsaurus/bin/entrypoint.sh"]
CMD ["mariadbd"]
