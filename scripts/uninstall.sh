#!/bin/bash

# WordPress Security Uninstallation Script
# For FastPanel with Nginx
# This script removes security rules from all sites

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

GOOGLE_MAP_PATH="/etc/nginx/fastpanel2-includes/googlebot-verified.map"
GOOGLE_HTTP_INCLUDE="/etc/nginx/fastpanel2-includes/googlebot-verify-http.conf"
NGINX_CONF_PATH="/etc/nginx/nginx.conf"

# Function to print colored output
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if FastPanel is installed
check_fastpanel() {
    if [[ ! -d "/etc/nginx/fastpanel2-sites" ]]; then
        print_error "FastPanel directory not found at /etc/nginx/fastpanel2-sites"
        print_error "Please ensure FastPanel is installed"
        exit 1
    fi
}

# Backup existing configurations before uninstall
backup_before_uninstall() {
    print_status "Creating backup before uninstall..."

    BACKUP_DIR="/root/pre-uninstall-backup-$(date +%F_%T)"
    cp -a /etc/nginx/fastpanel2-sites "$BACKUP_DIR"

    if [[ -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        cp /etc/nginx/fastpanel2-includes/wordpress-security.conf "$BACKUP_DIR/"
    fi

    if [[ -f "$GOOGLE_HTTP_INCLUDE" ]]; then
        cp "$GOOGLE_HTTP_INCLUDE" "$BACKUP_DIR/"
    fi

    if [[ -f "$GOOGLE_MAP_PATH" ]]; then
        cp "$GOOGLE_MAP_PATH" "$BACKUP_DIR/"
    fi

    print_success "Backup created at: $BACKUP_DIR"
}

# Remove security include from vhost configurations
remove_from_vhosts() {
    print_status "Removing security include from vhost configurations..."

    local count=0
    local vhost_array=()

    while IFS= read -r -d '' vhost; do
        vhost_array+=("$vhost")
    done < <(find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 2>/dev/null || true)

    if [[ ${#vhost_array[@]} -eq 0 ]]; then
        print_warning "No vhost configuration files found in /etc/nginx/fastpanel2-sites/"
        print_status "If your FastPanel stores configs elsewhere, update the script path accordingly."
        return 0
    fi

    for vhost in "${vhost_array[@]}"; do
        if grep -q "fastpanel2-includes" "$vhost"; then
            print_status "Removing include from: $vhost"
            sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"
            # Also remove the comment line
            sed -i '/# load security includes early/d' "$vhost"
            ((++count))
        fi
    done

    print_success "Removed security include from $count vhost configuration(s)"
}

# Remove security include file
remove_security_config() {
    print_status "Removing security configuration file..."

    if [[ -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        rm /etc/nginx/fastpanel2-includes/wordpress-security.conf
        print_success "Removed security configuration file"
    else
        print_warning "Security configuration file not found"
    fi
}

remove_googlebot_protection() {
    print_status "Removing Googlebot verification assets..."

    if [[ -f "$NGINX_CONF_PATH" ]] && grep -Fq "$GOOGLE_HTTP_INCLUDE" "$NGINX_CONF_PATH"; then
        local nginx_backup="/root/backup-nginx.conf-before-uninstall-$(date +%F_%T).conf"
        cp "$NGINX_CONF_PATH" "$nginx_backup"
        if sed -i "\#${GOOGLE_HTTP_INCLUDE}#d" "$NGINX_CONF_PATH"; then
            print_success "Removed Googlebot include from nginx.conf (backup: $nginx_backup)"
        else
            print_warning "Failed to update nginx.conf; restore from $nginx_backup if needed"
        fi
    fi

    if [[ -f "$GOOGLE_HTTP_INCLUDE" ]]; then
        rm "$GOOGLE_HTTP_INCLUDE"
        print_success "Removed Googlebot HTTP include"
    fi

    if [[ -f "$GOOGLE_MAP_PATH" ]]; then
        rm "$GOOGLE_MAP_PATH"
        print_success "Removed Googlebot CIDR map"
    fi

    local nightly_google_script="/usr/local/share/wp-security/update-googlebot-map.py"
    if [[ -f "$nightly_google_script" ]]; then
        rm "$nightly_google_script"
        print_success "Removed Googlebot updater script at $nightly_google_script"
    fi
}

# Test nginx configuration
test_nginx() {
    print_status "Testing nginx configuration..."

    if nginx -t; then
        print_success "Nginx configuration test passed"
        return 0
    else
        print_error "Nginx configuration test failed"
        return 1
    fi
}

# Reload nginx
reload_nginx() {
    print_status "Reloading nginx..."

    if systemctl reload nginx; then
        print_success "Nginx reloaded successfully"
    else
        print_error "Failed to reload nginx"
        return 1
    fi
}

# Verify uninstallation
verify_uninstall() {
    print_status "Verifying uninstallation..."

    if [[ -f "$GOOGLE_HTTP_INCLUDE" ]]; then
        print_warning "Googlebot HTTP include still exists at $GOOGLE_HTTP_INCLUDE"
    else
        print_success "Googlebot HTTP include removed"
    fi

    if [[ -f "$GOOGLE_MAP_PATH" ]]; then
        print_warning "Googlebot CIDR map still exists at $GOOGLE_MAP_PATH"
    else
        print_success "Googlebot CIDR map removed"
    fi

    # Check if security include file was removed
    if [[ ! -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        print_success "Security include file removed"
    else
        print_warning "Security include file still exists"
    fi

    # Check if vhosts still have the include
    local includes_found=0
    local vhost_array=()

    while IFS= read -r -d '' vhost; do
        vhost_array+=("$vhost")
    done < <(find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 2>/dev/null || true)

    for vhost in "${vhost_array[@]}"; do
        if grep -q "fastpanel2-includes" "$vhost"; then
            ((++includes_found))
        fi
    done

    if [[ $includes_found -eq 0 ]]; then
        print_success "Security include removed from all vhost configurations"
    else
        print_warning "Security include still found in $includes_found vhost configuration(s)"
    fi
}

# Main uninstall function
main() {
    print_status "Starting WordPress Security uninstallation for FastPanel..."
    echo
    print_warning "This will remove all WordPress security rules from your Nginx configuration."
    print_warning "Your sites will be less protected after this operation."
    echo

    # Ask for confirmation
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Uninstallation cancelled."
        exit 0
    fi

    echo

    # Run checks
    check_root
    check_fastpanel

    # Uninstall components
    backup_before_uninstall
    remove_from_vhosts
    remove_security_config
    remove_googlebot_protection

    # Test and reload
    if test_nginx; then
        reload_nginx
        verify_uninstall

        echo
        print_success "Uninstallation completed successfully!"
        echo
        print_status "Important notes:"
        echo "1. Your backup is located at: $BACKUP_DIR"
        echo "2. Your sites are no longer protected by these security rules"
        echo "3. Consider the security implications before proceeding"
        echo

    else
        print_error "Nginx configuration test failed. Please check the error above."
        print_error "You can restore from backup: $BACKUP_DIR"
        exit 1
    fi
}

# Run main function
main "$@"
