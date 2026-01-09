#!/bin/bash
# MariaDB Galera Health Check
# SPDX-License-Identifier: MIT

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/common.sh" 2>/dev/null || true

# =============================================================================
# Health Check
# =============================================================================

MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD:-}}"
export MYSQL_PWD

check_mysql_alive() {
    mysqladmin ping -u root --silent 2>/dev/null
}

check_wsrep_ready() {
    local ready
    ready=$(mysql -u root -N -e "SHOW STATUS LIKE 'wsrep_ready'" 2>/dev/null | awk '{print $2}')
    [[ "$ready" == "ON" ]]
}

check_wsrep_cluster_status() {
    local status
    status=$(mysql -u root -N -e "SHOW STATUS LIKE 'wsrep_cluster_status'" 2>/dev/null | awk '{print $2}')
    [[ "$status" == "Primary" ]]
}

check_wsrep_local_state() {
    local state
    state=$(mysql -u root -N -e "SHOW STATUS LIKE 'wsrep_local_state_comment'" 2>/dev/null | awk '{print $2}')
    [[ "$state" == "Synced" ]] || [[ "$state" == "Donor/Desynced" ]]
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Check 1: MySQL is alive
    if ! check_mysql_alive; then
        echo "UNHEALTHY: MySQL not responding"
        exit 1
    fi
    
    # Check 2: Galera wsrep_ready
    if ! check_wsrep_ready; then
        echo "UNHEALTHY: wsrep_ready is OFF"
        exit 1
    fi
    
    # Check 3: Cluster status is Primary
    if ! check_wsrep_cluster_status; then
        echo "UNHEALTHY: Not in Primary cluster"
        exit 1
    fi
    
    # Check 4: Node is synced
    if ! check_wsrep_local_state; then
        echo "UNHEALTHY: Node not synced"
        exit 1
    fi
    
    echo "HEALTHY: Galera node synced and ready"
    exit 0
}

main "$@"
