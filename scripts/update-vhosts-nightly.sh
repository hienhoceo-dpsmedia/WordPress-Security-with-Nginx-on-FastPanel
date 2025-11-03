#!/bin/bash

# WordPress Security — Nightly vhost refresh for FastPanel
# Ensures every vhost keeps the security include without re-running the full installer.

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

FASTPANEL_DIR="/etc/nginx/fastpanel2-sites"
INCLUDE_FILE="/etc/nginx/fastpanel2-includes/wordpress-security.conf"
GOOGLE_MAP_PATH="/etc/nginx/fastpanel2-includes/googlebot-verified.map"
GOOGLE_HTTP_INCLUDE="/etc/nginx/fastpanel2-includes/googlebot-verify-http.conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOOGLEBOT_UPDATE_SCRIPT="${SCRIPT_DIR}/update-googlebot-map.py"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

ensure_prerequisites() {
    if [[ ! -d "$FASTPANEL_DIR" ]]; then
        print_error "FastPanel vhost directory not found: $FASTPANEL_DIR"
        exit 1
    fi

    if [[ ! -f "$INCLUDE_FILE" ]]; then
        print_error "Security include missing: $INCLUDE_FILE"
        print_status "Re-run the main installer to recreate it."
        exit 1
    fi
}

refresh_googlebot_map() {
    if [[ ! -x "$GOOGLEBOT_UPDATE_SCRIPT" ]]; then
        print_warning "Googlebot updater script not found at $GOOGLEBOT_UPDATE_SCRIPT"
        return
    fi

    if python3 "$GOOGLEBOT_UPDATE_SCRIPT" --quiet --map-path "$GOOGLE_MAP_PATH" --http-include-path "$GOOGLE_HTTP_INCLUDE"; then
        print_success "Googlebot CIDR map refreshed"
    else
        print_warning "Failed to refresh Googlebot CIDR map"
    fi
}

create_backup() {
    local timestamp
    timestamp="$(date +%F_%T)"
    BACKUP_DIR="/root/backup-fastpanel2-sites-${timestamp}"
    cp -a "$FASTPANEL_DIR" "$BACKUP_DIR"
    print_success "Backup created at: $BACKUP_DIR"
}

refresh_vhosts() {
    local vhost_files=()
    local updated=0
    local skipped=0

    while IFS= read -r -d '' file; do
        vhost_files+=("$file")
    done < <(find "$FASTPANEL_DIR" -type f -name '*.conf' -print0 2>/dev/null || true)

    if [[ ${#vhost_files[@]} -eq 0 ]]; then
        print_warning "No vhost configuration files found under $FASTPANEL_DIR"
        return
    fi

    for vhost in "${vhost_files[@]}"; do
        print_status "Processing: $(basename "$vhost")"

        sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"
        sed -i '/# load security includes early/d' "$vhost"

        if grep -q "disable_symlinks if_not_owner from=\$root_path;" "$vhost"; then
            sed -i '/disable_symlinks if_not_owner from=\$root_path;/a\
    # load security includes early\
    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"
            ((updated++))
        else
            print_warning "disable_symlinks directive not found in $(basename "$vhost"); skipping automatic insert"
            ((skipped++))
        fi
    done

    print_success "Updated ${updated} vhost configuration(s)"
    if [[ $skipped -gt 0 ]]; then
        print_warning "${skipped} vhost(s) require manual review to add the include"
    fi
}

validate_and_reload() {
    if nginx -t; then
        print_success "Nginx configuration test passed"
        if systemctl reload nginx; then
            print_success "Nginx reloaded successfully"
        else
            print_error "Failed to reload nginx"
            return 1
        fi
    else
        print_error "Nginx configuration test failed"
        print_status "Restore from backup if necessary: $BACKUP_DIR"
        return 1
    fi
}

prune_old_backups() {
    find /root -maxdepth 1 -type d -name 'backup-fastpanel2-sites-*' -mtime +7 -print0 | xargs -0r rm -rf
}

main() {
    print_status "Starting nightly FastPanel vhost refresh"
    check_root
    ensure_prerequisites
    refresh_googlebot_map
    create_backup
    refresh_vhosts
    validate_and_reload
    prune_old_backups
    print_success "Nightly vhost refresh completed"
}

main "$@"
