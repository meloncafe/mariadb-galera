#!/bin/bash
# MariaDB Galera Health Check
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 devsaurus

set -euo pipefail

MARIADB_BASE_DIR="${MARIADB_BASE_DIR:-/usr/local/mysql}"
MARIADB_TMP_DIR="${MARIADB_TMP_DIR:-/var/run/mysqld}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"

mysql_cmd() {
    "${MARIADB_BASE_DIR}/bin/mysql" \
        --socket="${MARIADB_TMP_DIR}/mysqld.sock" \
        -u root \
        ${MARIADB_ROOT_PASSWORD:+-p"$MARIADB_ROOT_PASSWORD"} \
        -N -s \
        -e "$1" 2>/dev/null
}

# Check if MariaDB is running
if ! "${MARIADB_BASE_DIR}/bin/mysqladmin" \
    --socket="${MARIADB_TMP_DIR}/mysqld.sock" \
    ping &>/dev/null; then
    echo "MariaDB is not running"
    exit 1
fi

# Check wsrep status
wsrep_ready=$(mysql_cmd "SHOW STATUS LIKE 'wsrep_ready';" | awk '{print $2}')
if [[ "$wsrep_ready" != "ON" ]]; then
    echo "Galera wsrep not ready: $wsrep_ready"
    exit 1
fi

# Check cluster state
wsrep_cluster_status=$(mysql_cmd "SHOW STATUS LIKE 'wsrep_cluster_status';" | awk '{print $2}')
if [[ "$wsrep_cluster_status" != "Primary" ]]; then
    echo "Not in Primary cluster state: $wsrep_cluster_status"
    exit 1
fi

# Check local state
wsrep_local_state_comment=$(mysql_cmd "SHOW STATUS LIKE 'wsrep_local_state_comment';" | awk '{print $2}')
if [[ "$wsrep_local_state_comment" != "Synced" ]]; then
    echo "Node not synced: $wsrep_local_state_comment"
    exit 1
fi

# Optional: Check connected nodes (commented out - may not always be available)
# wsrep_cluster_size=$(mysql_cmd "SHOW STATUS LIKE 'wsrep_cluster_size';" | awk '{print $2}')
# echo "Cluster size: $wsrep_cluster_size"

echo "Healthy"
exit 0
