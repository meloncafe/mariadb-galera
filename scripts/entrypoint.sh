#!/bin/bash
# MariaDB Galera Cluster Entrypoint
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 devsaurus

set -euo pipefail

# =============================================================================
# Environment Variables with Defaults
# =============================================================================

# Directories
export MARIADB_BASE_DIR="${MARIADB_BASE_DIR:-/usr/local/mysql}"
export MARIADB_DATA_DIR="${MARIADB_DATA_DIR:-/var/lib/mysql}"
export MARIADB_CONF_DIR="${MARIADB_CONF_DIR:-/etc/mysql}"
export MARIADB_LOG_DIR="${MARIADB_LOG_DIR:-/var/log/mysql}"
export MARIADB_TMP_DIR="${MARIADB_TMP_DIR:-/var/run/mysqld}"

# Server Configuration
export MARIADB_PORT="${MARIADB_PORT:-3306}"
export MARIADB_BIND_ADDRESS="${MARIADB_BIND_ADDRESS:-0.0.0.0}"
export MARIADB_CHARACTER_SET="${MARIADB_CHARACTER_SET:-utf8mb4}"
export MARIADB_COLLATION="${MARIADB_COLLATION:-utf8mb4_unicode_ci}"

# Authentication
export MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-}"
export MARIADB_ROOT_HOST="${MARIADB_ROOT_HOST:-%}"
export MARIADB_USER="${MARIADB_USER:-}"
export MARIADB_PASSWORD="${MARIADB_PASSWORD:-}"
export MARIADB_DATABASE="${MARIADB_DATABASE:-}"
export ALLOW_EMPTY_PASSWORD="${ALLOW_EMPTY_PASSWORD:-no}"

# Galera Configuration
export GALERA_CLUSTER_NAME="${GALERA_CLUSTER_NAME:-galera_cluster}"
export GALERA_CLUSTER_ADDRESS="${GALERA_CLUSTER_ADDRESS:-}"
export GALERA_CLUSTER_BOOTSTRAP="${GALERA_CLUSTER_BOOTSTRAP:-}"
export GALERA_NODE_NAME="${GALERA_NODE_NAME:-$(hostname)}"
export GALERA_NODE_ADDRESS="${GALERA_NODE_ADDRESS:-}"
export GALERA_SST_METHOD="${GALERA_SST_METHOD:-mariabackup}"
export GALERA_SST_USER="${GALERA_SST_USER:-mariabackup}"
export GALERA_SST_PASSWORD="${GALERA_SST_PASSWORD:-}"
export GALERA_FORCE_BOOTSTRAP="${GALERA_FORCE_BOOTSTRAP:-no}"

# Galera Provider
export GALERA_PROVIDER="${GALERA_PROVIDER:-/usr/lib/galera/libgalera_smm.so}"

# Internal
export GRASTATE_FILE="${MARIADB_DATA_DIR}/grastate.dat"
export BOOTSTRAP_MARKER="${MARIADB_DATA_DIR}/.bootstrap_done"

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*"
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

is_boolean_yes() {
    local val="${1:-}"
    case "${val,,}" in
        yes|true|1|on) return 0 ;;
        *) return 1 ;;
    esac
}

wait_for_service() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local start_time=$(date +%s)
    
    log_info "Waiting for ${host}:${port}..."
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [[ $(($(date +%s) - start_time)) -ge $timeout ]]; then
            log_error "Timeout waiting for ${host}:${port}"
            return 1
        fi
        sleep 1
    done
    log_info "Service ${host}:${port} is available"
}

get_local_ip() {
    hostname -I | awk '{print $1}'
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_environment() {
    log_info "Validating environment configuration..."
    
    # Check password requirements
    if [[ -z "$MARIADB_ROOT_PASSWORD" ]] && ! is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
        log_error "MARIADB_ROOT_PASSWORD must be set (or set ALLOW_EMPTY_PASSWORD=yes)"
        exit 1
    fi
    
    # Galera SST password required for cluster mode
    if [[ -n "$GALERA_CLUSTER_ADDRESS" ]] && [[ -z "$GALERA_SST_PASSWORD" ]]; then
        log_error "GALERA_SST_PASSWORD is required for cluster mode"
        exit 1
    fi
    
    # Validate SST method
    case "$GALERA_SST_METHOD" in
        mariabackup|rsync|mysqldump) ;;
        *)
            log_error "Invalid GALERA_SST_METHOD: $GALERA_SST_METHOD"
            exit 1
            ;;
    esac
    
    log_info "Environment validation passed"
}

# =============================================================================
# Directory Setup
# =============================================================================

setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p "$MARIADB_DATA_DIR" "$MARIADB_LOG_DIR" "$MARIADB_TMP_DIR" "$MARIADB_CONF_DIR/conf.d"
    
    # Set ownership (mysql user should be created in Dockerfile)
    chown -R mysql:mysql "$MARIADB_DATA_DIR" "$MARIADB_LOG_DIR" "$MARIADB_TMP_DIR"
    chmod 750 "$MARIADB_DATA_DIR"
    
    log_info "Directories configured"
}

# =============================================================================
# Configuration Generation
# =============================================================================

generate_server_config() {
    log_info "Generating MariaDB server configuration..."
    
    cat > "${MARIADB_CONF_DIR}/my.cnf" << EOF
# MariaDB Galera Cluster Configuration
# Auto-generated by entrypoint.sh

[client]
port = ${MARIADB_PORT}
socket = ${MARIADB_TMP_DIR}/mysqld.sock
default-character-set = ${MARIADB_CHARACTER_SET}

[mysqld]
# Basic Settings
user = mysql
port = ${MARIADB_PORT}
bind-address = ${MARIADB_BIND_ADDRESS}
socket = ${MARIADB_TMP_DIR}/mysqld.sock
pid-file = ${MARIADB_TMP_DIR}/mysqld.pid
basedir = ${MARIADB_BASE_DIR}
datadir = ${MARIADB_DATA_DIR}
tmpdir = /tmp

# Character Set
character-set-server = ${MARIADB_CHARACTER_SET}
collation-server = ${MARIADB_COLLATION}

# Logging
log-error = ${MARIADB_LOG_DIR}/error.log
log_warnings = 2

# InnoDB Settings (optimized for Galera)
default_storage_engine = InnoDB
innodb_autoinc_lock_mode = 2
innodb_flush_log_at_trx_commit = 2
innodb_buffer_pool_size = 256M

# Binary Logging (required for Galera)
binlog_format = ROW
log_bin = ${MARIADB_DATA_DIR}/mysql-bin

# Galera Settings
wsrep_on = ON
wsrep_provider = ${GALERA_PROVIDER}
wsrep_cluster_name = ${GALERA_CLUSTER_NAME}
wsrep_cluster_address = gcomm://
wsrep_node_name = ${GALERA_NODE_NAME}
wsrep_node_address = ${GALERA_NODE_ADDRESS:-$(get_local_ip)}
wsrep_sst_method = ${GALERA_SST_METHOD}
wsrep_sst_auth = "${GALERA_SST_USER}:${GALERA_SST_PASSWORD}"

# Galera Cache
wsrep_provider_options = "gcache.size=256M"

!includedir ${MARIADB_CONF_DIR}/conf.d/
EOF

    log_info "Configuration generated at ${MARIADB_CONF_DIR}/my.cnf"
}

update_cluster_address() {
    local address="$1"
    log_info "Updating cluster address to: $address"
    sed -i "s|^wsrep_cluster_address = .*|wsrep_cluster_address = ${address}|" "${MARIADB_CONF_DIR}/my.cnf"
}

# =============================================================================
# Database Initialization
# =============================================================================

is_db_initialized() {
    [[ -d "${MARIADB_DATA_DIR}/mysql" ]]
}

initialize_database() {
    log_info "Initializing MariaDB database..."
    
    "${MARIADB_BASE_DIR}/scripts/mariadb-install-db" \
        --user=mysql \
        --datadir="$MARIADB_DATA_DIR" \
        --basedir="$MARIADB_BASE_DIR" \
        --auth-root-authentication-method=normal \
        2>&1 | while read -r line; do log_debug "$line"; done
    
    log_info "Database initialized"
}

start_mariadb_standalone() {
    log_info "Starting MariaDB in standalone mode for initial setup..."
    
    "${MARIADB_BASE_DIR}/bin/mysqld" \
        --defaults-file="${MARIADB_CONF_DIR}/my.cnf" \
        --user=mysql \
        --skip-networking \
        --wsrep-on=OFF \
        --socket="${MARIADB_TMP_DIR}/mysqld.sock" &
    
    local pid=$!
    local timeout=60
    local elapsed=0
    
    while ! "${MARIADB_BASE_DIR}/bin/mysqladmin" \
            --socket="${MARIADB_TMP_DIR}/mysqld.sock" \
            ping &>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            log_error "Timeout waiting for MariaDB to start"
            return 1
        fi
        sleep 1
        ((elapsed++))
    done
    
    log_info "MariaDB standalone started (PID: $pid)"
    echo $pid
}

stop_mariadb() {
    log_info "Stopping MariaDB..."
    "${MARIADB_BASE_DIR}/bin/mysqladmin" \
        --socket="${MARIADB_TMP_DIR}/mysqld.sock" \
        shutdown 2>/dev/null || true
    sleep 2
}

run_sql() {
    "${MARIADB_BASE_DIR}/bin/mysql" \
        --socket="${MARIADB_TMP_DIR}/mysqld.sock" \
        -u root \
        -e "$1"
}

setup_root_user() {
    log_info "Configuring root user..."
    
    if [[ -n "$MARIADB_ROOT_PASSWORD" ]]; then
        run_sql "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"
        run_sql "CREATE USER IF NOT EXISTS 'root'@'${MARIADB_ROOT_HOST}' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"
        run_sql "GRANT ALL PRIVILEGES ON *.* TO 'root'@'${MARIADB_ROOT_HOST}' WITH GRANT OPTION;"
    fi
    
    run_sql "FLUSH PRIVILEGES;"
    log_info "Root user configured"
}

setup_sst_user() {
    log_info "Creating SST user for Galera..."
    
    run_sql "CREATE USER IF NOT EXISTS '${GALERA_SST_USER}'@'localhost' IDENTIFIED BY '${GALERA_SST_PASSWORD}';"
    run_sql "GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${GALERA_SST_USER}'@'localhost';"
    
    # For mariabackup SST method
    if [[ "$GALERA_SST_METHOD" == "mariabackup" ]]; then
        run_sql "GRANT CREATE TABLESPACE, SUPER ON *.* TO '${GALERA_SST_USER}'@'localhost';"
    fi
    
    run_sql "FLUSH PRIVILEGES;"
    log_info "SST user created"
}

setup_application_user() {
    if [[ -n "$MARIADB_USER" ]] && [[ -n "$MARIADB_PASSWORD" ]]; then
        log_info "Creating application user: $MARIADB_USER"
        
        run_sql "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';"
        
        if [[ -n "$MARIADB_DATABASE" ]]; then
            run_sql "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;"
            run_sql "GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';"
        fi
        
        run_sql "FLUSH PRIVILEGES;"
        log_info "Application user created"
    fi
}

run_init_scripts() {
    if [[ -d /docker-entrypoint-initdb.d ]]; then
        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sh)
                    log_info "Running init script: $f"
                    . "$f"
                    ;;
                *.sql)
                    log_info "Running SQL file: $f"
                    "${MARIADB_BASE_DIR}/bin/mysql" \
                        --socket="${MARIADB_TMP_DIR}/mysqld.sock" \
                        -u root \
                        ${MARIADB_ROOT_PASSWORD:+-p"$MARIADB_ROOT_PASSWORD"} \
                        < "$f"
                    ;;
            esac
        done
    fi
}

# =============================================================================
# Galera Cluster Functions
# =============================================================================

check_other_nodes_available() {
    # Parse cluster address and check if any node is reachable
    local cluster_addr="${GALERA_CLUSTER_ADDRESS#gcomm://}"
    
    if [[ -z "$cluster_addr" ]]; then
        return 1
    fi
    
    local IFS=','
    local nodes=($cluster_addr)
    local my_ip=$(get_local_ip)
    
    for node in "${nodes[@]}"; do
        local host="${node%%:*}"
        local port="${node##*:}"
        [[ "$port" == "$host" ]] && port=4567
        
        # Skip self
        local node_ip
        node_ip=$(getent hosts "$host" 2>/dev/null | awk '{print $1}' | head -1)
        if [[ "$node_ip" == "$my_ip" ]] || [[ "$host" == "$my_ip" ]]; then
            continue
        fi
        
        # Check if node is reachable
        if nc -z "$host" "$port" 2>/dev/null; then
            log_info "Found active cluster node: $host:$port"
            return 0
        fi
    done
    
    return 1
}

is_safe_to_bootstrap() {
    if [[ -f "$GRASTATE_FILE" ]]; then
        grep -q "safe_to_bootstrap: 1" "$GRASTATE_FILE" 2>/dev/null
    else
        return 1
    fi
}

set_safe_to_bootstrap() {
    if [[ -f "$GRASTATE_FILE" ]]; then
        sed -i 's/safe_to_bootstrap: 0/safe_to_bootstrap: 1/' "$GRASTATE_FILE"
        log_info "Set safe_to_bootstrap to 1"
    fi
}

should_bootstrap() {
    # Explicit bootstrap requested
    if is_boolean_yes "$GALERA_CLUSTER_BOOTSTRAP"; then
        log_info "Bootstrap requested via GALERA_CLUSTER_BOOTSTRAP"
        return 0
    fi
    
    # Force bootstrap (for recovery)
    if is_boolean_yes "$GALERA_FORCE_BOOTSTRAP"; then
        log_warn "Force bootstrap enabled - use with caution!"
        set_safe_to_bootstrap
        return 0
    fi
    
    # First time setup - no data, no other nodes
    if ! is_db_initialized && ! check_other_nodes_available; then
        log_info "First node in cluster, will bootstrap"
        return 0
    fi
    
    # Has data and marked safe to bootstrap, no other nodes
    if is_safe_to_bootstrap && ! check_other_nodes_available; then
        log_info "Safe to bootstrap and no other nodes found"
        return 0
    fi
    
    return 1
}

get_cluster_address() {
    if should_bootstrap; then
        echo "gcomm://"
    else
        echo "gcomm://${GALERA_CLUSTER_ADDRESS#gcomm://}"
    fi
}

# =============================================================================
# Main Startup Logic
# =============================================================================

main() {
    log_info "============================================"
    log_info "MariaDB Galera Cluster - Starting"
    log_info "============================================"
    
    # Validate configuration
    validate_environment
    
    # Setup directories
    setup_directories
    
    # Generate configuration
    generate_server_config
    
    # Initialize database if needed
    if ! is_db_initialized; then
        log_info "Database not initialized, performing first-time setup..."
        
        initialize_database
        
        # Start temporarily for user setup
        local setup_pid
        setup_pid=$(start_mariadb_standalone)
        
        setup_root_user
        setup_sst_user
        setup_application_user
        run_init_scripts
        
        stop_mariadb
        
        log_info "First-time setup completed"
    fi
    
    # Determine cluster address
    local cluster_address
    cluster_address=$(get_cluster_address)
    update_cluster_address "$cluster_address"
    
    if [[ "$cluster_address" == "gcomm://" ]]; then
        log_info "Starting as bootstrap node (new cluster)"
    else
        log_info "Joining existing cluster: $cluster_address"
    fi
    
    # Start MariaDB with Galera
    log_info "Starting MariaDB Galera Cluster..."
    log_info "============================================"
    
    exec "${MARIADB_BASE_DIR}/bin/mysqld" \
        --defaults-file="${MARIADB_CONF_DIR}/my.cnf" \
        --user=mysql \
        "$@"
}

# Handle signals
trap 'log_info "Received SIGTERM, shutting down..."; kill -TERM $!; wait' SIGTERM
trap 'log_info "Received SIGINT, shutting down..."; kill -INT $!; wait' SIGINT

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
