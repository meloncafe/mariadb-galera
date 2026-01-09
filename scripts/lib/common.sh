#!/bin/bash
# Devsaurus common functions
# SPDX-License-Identifier: MIT

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
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

wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-30}"
    local start_time
    start_time=$(date +%s)

    log_info "Waiting for ${host}:${port}..."
    while ! nc -z "$host" "$port" 2>/dev/null; do
        local current_time
        current_time=$(date +%s)
        if [[ $((current_time - start_time)) -ge $timeout ]]; then
            log_error "Timeout waiting for ${host}:${port}"
            return 1
        fi
        sleep 1
    done
    log_info "Service ${host}:${port} is available"
}

get_local_ip() {
    hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
}

# =============================================================================
# File Helpers
# =============================================================================

ensure_dir() {
    local dir="$1"
    local owner="${2:-}"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi

    if [[ -n "$owner" ]]; then
        chown "$owner" "$dir"
    fi
}
