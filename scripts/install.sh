#!/bin/bash

# WordPress Security Installation Script
# For FastPanel with Nginx
# This script installs security rules and configures all sites

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository URLs
RAW_BASE_URL="https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master"

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

# Ensure required dependencies exist
ensure_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed. Please install curl and re-run this script."
        exit 1
    fi

    if ! command -v crontab >/dev/null 2>&1; then
        print_error "crontab command not found. Install cron (e.g., cron, cronie) before proceeding."
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

# Configure nightly automation
setup_nightly_automation() {
    print_status "Configuring nightly automation..."

    local automation_script="/usr/local/sbin/wp-security-nightly.sh"
    local nightly_dir="/usr/local/share/wp-security"
    local nightly_script="${nightly_dir}/update-vhosts-nightly.sh"
    local cron_entry="30 2 * * * ${automation_script} >> /var/log/wp-security-nightly.log 2>&1"
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local source_script="${repo_root}/scripts/update-vhosts-nightly.sh"

    if [[ ! -f "$source_script" ]]; then
        print_error "Nightly updater script missing from repository: $source_script"
        exit 1
    fi

    mkdir -p "$nightly_dir"
    cp "$source_script" "$nightly_script"
    chmod 755 "$nightly_script"
    print_success "Nightly updater installed at $nightly_script"

    cat <<EOF > "$automation_script"
#!/bin/bash
set -euo pipefail
"$nightly_script"
EOF
    chmod +x "$automation_script"
    print_success "Nightly automation script ready at $automation_script"

    if crontab -l 2>/dev/null | grep -F "$automation_script" >/dev/null 2>&1; then
        print_status "Nightly cron job already configured"
    else
        (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
        print_success "Scheduled nightly cron job at 02:30 for WordPress security automation"
    fi
}

# Create nginx includes directory if it doesn't exist
create_includes_dir() {
    print_status "Creating nginx includes directory..."
    mkdir -p /etc/nginx/fastpanel2-includes
    print_success "Created /etc/nginx/fastpanel2-includes"
}

# Install the security configuration
install_security_config() {
    print_status "Installing WordPress security configuration..."

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SECURITY_CONF="$SCRIPT_DIR/../nginx-includes/wordpress-security.conf"

    if [[ ! -f "$SECURITY_CONF" ]]; then
        print_error "Security configuration file not found: $SECURITY_CONF"
        exit 1
    fi

    # Copy the security configuration
    cp "$SECURITY_CONF" /etc/nginx/fastpanel2-includes/wordpress-security.conf
    chmod 644 /etc/nginx/fastpanel2-includes/wordpress-security.conf

    print_success "Security configuration installed"
}

# Backup existing vhost configurations
backup_vhosts() {
    print_status "Creating backup of existing vhost configurations..."

    BACKUP_DIR="/root/backup-fastpanel2-sites-$(date +%F_%T)"
    cp -a /etc/nginx/fastpanel2-sites "$BACKUP_DIR"

    print_success "Backup created at: $BACKUP_DIR"
}

# Update vhost configurations
update_vhosts() {
    print_status "Updating vhost configurations..."

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
        print_status "Processing: $vhost"

        # Remove any existing include lines to avoid duplicates
        sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"
        sed -i '/# load security includes early/d' "$vhost"

        # Insert the include after disable_symlinks line
        if grep -q "disable_symlinks if_not_owner from=\$root_path;" "$vhost"; then
            sed -i '/disable_symlinks if_not_owner from=\$root_path;/a\
    # load security includes early\
    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"
            ((++count))
        else
            print_warning "Could not find disable_symlinks directive in $vhost"
        fi
    done

    print_success "Updated $count vhost configuration(s)"
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

# Verify installation
verify_installation() {
    print_status "Verifying installation..."

    # Check if security include exists
    if [[ -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        print_success "Security include file exists"
    else
        print_error "Security include file missing"
        return 1
    fi

    # Check if vhosts include the security config
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

    if [[ $includes_found -gt 0 ]]; then
        print_success "Security include found in $includes_found vhost configuration(s)"
    else
        print_warning "Security include not found in any vhost configuration"
    fi
}

# Main installation function
main() {
    print_status "Starting WordPress Security installation for FastPanel..."
    echo

    # Run checks
    check_root
    check_fastpanel
    ensure_dependencies

    # Install components
    create_includes_dir
    install_security_config
    backup_vhosts
    update_vhosts

    # Test and reload
    if test_nginx; then
        reload_nginx
        verify_installation

        setup_nightly_automation

        echo
        print_success "Installation completed successfully!"
        echo
        print_status "Next steps:"
        echo "1. Test your security configuration with: ./scripts/test-security.sh"
        echo "2. Check the test results to ensure sensitive files return 403"
        echo "3. Monitor your logs for any blocked attempts"
        echo
        print_status "Your backup is located at: $BACKUP_DIR"
        print_status "Nightly automation script: /usr/local/sbin/wp-security-nightly.sh → /usr/local/share/wp-security/update-vhosts-nightly.sh (02:30 daily)"

    else
        print_error "Nginx configuration test failed. Please check the error above."
        print_error "You can restore from backup: $BACKUP_DIR"
        exit 1
    fi
}

# Run main function
main "$@"
