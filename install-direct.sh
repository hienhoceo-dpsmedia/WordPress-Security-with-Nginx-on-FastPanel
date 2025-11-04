#!/bin/bash

# WordPress Security Direct Installation Script
# Combined installation - download config and update vhosts in one script

set -Eeuo pipefail

# Repository URLs
RAW_URL="https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

GOOGLE_MAP_PATH="/etc/nginx/fastpanel2-includes/googlebot-verified.map"
GOOGLE_HTTP_INCLUDE="/etc/nginx/fastpanel2-includes/googlebot-verify-http.mapinc"
GOOGLE_HTTP_BRIDGE="/etc/nginx/conf.d/wp-googlebot-verify.conf"

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

print_header() {
    echo
    echo -e "${BLUE}=== $1 ===${NC}"
}

trap 'print_error "Installation aborted (line $LINENO): $BASH_COMMAND"; exit 1' ERR

# Repository URLs
REPO_URL="https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel"

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

# Ensure required tools exist
ensure_dependencies() {
    local missing=0

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        print_error "Neither curl nor wget is installed. Install one of them and re-run this script."
        missing=1
    fi

    if ! command -v crontab >/dev/null 2>&1; then
        print_error "crontab command not found. Install cron (cron, cronie, etc.) before proceeding."
        missing=1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        print_error "python3 is required but not installed. Please install python3 and re-run this script."
        missing=1
    fi

    if [[ $missing -ne 0 ]]; then
        exit 1
    fi
}

# Helper to download files with curl or wget
fetch_file() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    else
        wget -qO "$output" "$url"
    fi
}

# Configure nightly automation
setup_nightly_automation() {
    print_header "Configuring Nightly Automation"

    local automation_script="/usr/local/sbin/wp-security-nightly.sh"
    local nightly_dir="/usr/local/share/wp-security"
    local nightly_script="${nightly_dir}/update-vhosts-nightly.sh"
    local googlebot_script="${nightly_dir}/update-googlebot-map.py"
    local nightly_lib_dir="${nightly_dir}/lib"
    local cron_entry="30 2 * * * ${automation_script} >> /var/log/wp-security-nightly.log 2>&1"

    mkdir -p "$nightly_dir"

    print_status "Installing nightly vhost updater..."
    if fetch_file "$RAW_URL/scripts/update-vhosts-nightly.sh" "$nightly_script"; then
        chmod +x "$nightly_script"
        print_success "Nightly updater stored at $nightly_script"
    else
        print_error "Failed to install nightly updater script"
        exit 1
    fi

    print_status "Ensuring Googlebot map updater..."
    if fetch_file "$RAW_URL/scripts/update-googlebot-map.py" "$googlebot_script"; then
        chmod +x "$googlebot_script"
        print_success "Googlebot map updater stored at $googlebot_script"
    else
        print_error "Failed to install Googlebot map updater script"
        exit 1
    fi

    print_status "Installing shared helper library..."
    mkdir -p "$nightly_lib_dir"
    if fetch_file "$RAW_URL/scripts/lib/common.sh" "${nightly_lib_dir}/common.sh"; then
        chmod 755 "${nightly_lib_dir}/common.sh"
        print_success "Shared helpers stored at ${nightly_lib_dir}/common.sh"
    else
        print_error "Failed to install shared helper library"
        exit 1
    fi

    cat <<EOF > "$automation_script"
#!/bin/bash
set -euo pipefail
python3 "$googlebot_script" --quiet || { echo "[WARNING] googlebot map refresh failed" >&2; }
"$nightly_script"
EOF
    chmod +x "$automation_script"
    print_success "Nightly automation script ready at $automation_script"

    if crontab -l 2>/dev/null | grep -F "$automation_script" >/dev/null 2>&1; then
        print_status "Nightly cron job already configured"
    else
        (crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
        print_success "Scheduled nightly cron job at 02:30"
    fi

    print_status "Nightly automation installed. Logs: /var/log/wp-security-nightly.log"
}

# Download and install security configuration
install_security_config() {
    print_header "Installing WordPress Security Configuration"

    # Create nginx includes directory if it doesn't exist
    mkdir -p /etc/nginx/fastpanel2-includes
    print_success "Created /etc/nginx/fastpanel2-includes"

    # Download the security configuration
    print_status "Downloading security configuration..."
    if fetch_file "$RAW_URL/nginx-includes/wordpress-security.conf" "/etc/nginx/fastpanel2-includes/wordpress-security.conf"; then
        print_success "Security configuration downloaded successfully"
    else
        print_error "Failed to download security configuration"
        exit 1
    fi

    # Set proper permissions
    chmod 644 /etc/nginx/fastpanel2-includes/wordpress-security.conf
    print_success "Set permissions on security configuration"
}

ensure_googlebot_http_include() {
    local include_line="include $GOOGLE_HTTP_INCLUDE;"
    mkdir -p /etc/nginx/conf.d

    if [[ -f "$GOOGLE_HTTP_BRIDGE" ]] && grep -Fq "$include_line" "$GOOGLE_HTTP_BRIDGE"; then
        print_status "Googlebot HTTP bridge already present at $GOOGLE_HTTP_BRIDGE"
        return 0
    fi

    cat <<EOF > "$GOOGLE_HTTP_BRIDGE"
# Managed by WordPress Security with Nginx on FastPanel
# Ensures Googlebot verification variables are defined at http{} scope.
$include_line
EOF
    chmod 644 "$GOOGLE_HTTP_BRIDGE"
    print_success "Created Googlebot HTTP bridge at $GOOGLE_HTTP_BRIDGE"
}

install_googlebot_protection() {
    print_header "Installing Googlebot Verification"

    mkdir -p /etc/nginx/fastpanel2-includes
    ensure_googlebot_http_include

    local nightly_dir="/usr/local/share/wp-security"
    local googlebot_script="${nightly_dir}/update-googlebot-map.py"

    mkdir -p "$nightly_dir"

    print_status "Downloading Googlebot map script..."
    if fetch_file "$RAW_URL/scripts/update-googlebot-map.py" "$googlebot_script"; then
        chmod +x "$googlebot_script"
        print_success "Googlebot map script stored at $googlebot_script"
    else
        print_error "Failed to download Googlebot map script"
        exit 1
    fi

    if python3 "$googlebot_script" --map-path "$GOOGLE_MAP_PATH" --http-include-path "$GOOGLE_HTTP_INCLUDE"; then
        print_success "Googlebot verification data generated"
    else
        print_error "Failed to generate Googlebot verification data"
        exit 1
    fi
}

# Backup existing vhost configurations
backup_vhosts() {
    print_header "Creating Backup of Existing Configurations"

    BACKUP_DIR="/root/backup-fastpanel2-sites-$(date +%F_%T)"
    if cp -a /etc/nginx/fastpanel2-sites "$BACKUP_DIR"; then
        print_success "Backup created at: $BACKUP_DIR"
    else
        print_error "Failed to create backup"
        exit 1
    fi
}

# Update vhost configurations
update_vhosts() {
    print_header "Updating Virtual Host Configurations"

    local count=0
    local total=0
    local failed=0
    local vhost_array=()

    while IFS= read -r -d '' vhost; do
        vhost_array+=("$vhost")
    done < <(find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 2>/dev/null || true)

    total=${#vhost_array[@]}

    if [[ $total -eq 0 ]]; then
        print_warning "No vhost configuration files found in /etc/nginx/fastpanel2-sites/"
        print_status "If your FastPanel stores configs elsewhere, update the script path accordingly."
        return 0
    fi

    print_status "Found $total vhost configuration(s) to update"

    # Update each vhost configuration with error handling
    for vhost in "${vhost_array[@]}"; do
        if [[ -f "$vhost" ]]; then
            print_status "Processing: $(basename "$vhost")"

            # Create backup of this specific vhost
            local backup_name="${vhost}.backup.$(date +%s)"
            if ! cp "$vhost" "$backup_name"; then
                print_error "Failed to backup $vhost"
                ((++failed))
                continue
            fi

            # Remove any existing include lines to avoid duplicates
            if ! sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"; then
                print_error "Failed to remove existing includes from $(basename "$vhost")"
                ((++failed))
                continue
            fi
            sed -i '/# load security includes early/d' "$vhost"

            # Check if disable_symlinks line exists and insert include after it
            if grep -q "disable_symlinks if_not_owner from=\$root_path;" "$vhost"; then
                if sed -i '/disable_symlinks if_not_owner from=\$root_path;/a\
    # load security includes early\
    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"; then
                    ((++count))
                    print_success "✓ Added security include to $(basename "$vhost")"
                else
                    print_error "✗ Failed to add include to $(basename "$vhost")"
                    ((++failed))
                    mv "$backup_name" "$vhost"
                fi
            else
                print_warning "⚠ Could not find disable_symlinks directive in $(basename "$vhost")"
                print_status "  Attempting alternative placement..."

                # Alternative: add include at the end of server block
                if grep -q "listen.*80" "$vhost" && grep -q "listen.*443" "$vhost"; then
                    if sed -i '/listen.*443/a\
    # load security includes early\
    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"; then
                        ((++count))
                        print_success "✓ Added security include (alternative placement) to $(basename "$vhost")"
                    else
                        print_error "✗ Failed to add include to $(basename "$vhost")"
                        ((++failed))
                        mv "$backup_name" "$vhost"
                    fi
                else
                    print_warning "⚠ Could not find suitable placement in $(basename "$vhost")"
                    print_status "  You may need to manually add the include line to this file"
                    ((++failed))
                fi
            fi

            # Remove backup if successful (only for this specific vhost)
            rm -f "$backup_name" 2>/dev/null
        fi

        # Progress indicator
        echo -n "Progress: $((count + failed))/$total processed"
        if [[ $((count + failed)) -lt $total ]]; then
            echo -n "..."
        fi
        echo
    done

    print_success "Successfully updated $count out of $total vhost configuration(s)"
    if [[ $failed -gt 0 ]]; then
        print_warning "$failed vhost(s) failed to update - check error messages above"
    fi
}

# Test nginx configuration
test_nginx() {
    print_header "Testing Nginx Configuration"

    if nginx -t; then
        print_success "✓ Nginx configuration test passed"
        return 0
    else
        print_error "✗ Nginx configuration test failed"
        print_error "Please check the error messages above and fix the configuration"
        print_status "You can restore from backup: $BACKUP_DIR"
        return 1
    fi
}

# Reload nginx
reload_nginx() {
    print_header "Reloading Nginx"

    if systemctl reload nginx; then
        print_success "✓ Nginx reloaded successfully"
    else
        print_error "✗ Failed to reload nginx"
        return 1
    fi
}

# Verify installation
verify_installation() {
    print_header "Verifying Installation"

    if [[ -f "$GOOGLE_HTTP_INCLUDE" ]]; then
        print_success "✓ Googlebot HTTP include exists"
    else
        print_warning "⚠ Googlebot HTTP include missing at $GOOGLE_HTTP_INCLUDE"
    fi

    if [[ -f "$GOOGLE_MAP_PATH" ]]; then
        print_success "✓ Googlebot CIDR map exists"
    else
        print_warning "⚠ Googlebot CIDR map missing at $GOOGLE_MAP_PATH"
    fi

    if [[ -f "$GOOGLE_HTTP_BRIDGE" ]]; then
        print_success "✓ Googlebot HTTP bridge exists at $GOOGLE_HTTP_BRIDGE"
    else
        print_warning "⚠ Googlebot HTTP bridge missing at $GOOGLE_HTTP_BRIDGE"
    fi

    # Check if security include exists
    if [[ -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        print_success "✓ Security include file exists"
    else
        print_error "✗ Security include file missing"
        return 1
    fi

    # Count total and updated vhosts
    local total_vhosts=0
    local includes_found=0
    local missing_sites=()
    local vhost_array=()

    while IFS= read -r -d '' vhost; do
        vhost_array+=("$vhost")
    done < <(find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 2>/dev/null || true)

    total_vhosts=${#vhost_array[@]}

    for vhost in "${vhost_array[@]}"; do
        if grep -q "fastpanel2-includes" "$vhost"; then
            ((++includes_found))
        else
            missing_sites+=("$(basename "$vhost")")
        fi
    done

    if [[ $includes_found -gt 0 ]]; then
        print_success "✓ Security include found in $includes_found/$total_vhosts vhost configuration(s)"

        if [[ $includes_found -eq $total_vhosts ]]; then
            print_success "✅ All WordPress sites are now protected!"
        else
            print_warning "⚠ ${#missing_sites[@]} site(s) missing security protection:"
            for site in "${missing_sites[@]}"; do
                print_status "  - $site"
            done
            print_status ""
            print_status "To fix remaining sites manually, run:"
            print_status "find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 | \\"
            print_status "while IFS= read -r -d '' conf_file; do"
            print_status "  if [[ -f \"\$conf_file\" ]] && ! grep -q \"fastpanel2-includes\" \"\$conf_file\"; then"
            print_status "    sed -i '/include \\/etc\\/nginx\\/fastpanel2-includes\\/\\*\\.conf;/d' \"\$conf_file\""
            print_status "    sed -i '/disable_symlinks if_not_owner from=\\$root_path;/a\\\\    # load security includes early\\\\    include /etc/nginx/fastpanel2-includes/*.conf;' \"\$conf_file\""
            print_status "  fi"
            print_status "done < /dev/stdin"
            print_status "nginx -t && systemctl reload nginx"
        fi
    else
        print_error "✗ Security include not found in any vhost configuration"
        print_status "  This indicates the installation failed to update any vhosts"
        return 1
    fi
}

# Show completion message
show_completion() {
    print_header "Installation Complete!"
    echo
    print_success "✅ WordPress security rules have been installed successfully!"
    echo
    print_status "What was installed:"
    echo "  • Nginx security rules to block common WordPress attacks"
    echo "  • PHP execution protection in uploads directory"
    echo "  • Sensitive file access blocking"
    echo "  • Backup and development file protection"
    echo "  • Known exploit pattern blocking"
    echo "  • Fake Googlebot detection via IP range verification"
    echo
    print_status "Next steps:"
    echo "1. Test your security: curl -s $RAW_URL/scripts/test-security.sh | bash -s your-domain.com"
    echo "2. Monitor your Nginx logs for blocked attacks"
    echo
    print_status "Backup location: $BACKUP_DIR"
    print_status "Repository: $REPO_URL"
    echo
    print_status "Nightly automation: /usr/local/sbin/wp-security-nightly.sh → /usr/local/share/wp-security/update-vhosts-nightly.sh (02:30)"
    print_status "Googlebot map updater: /usr/local/share/wp-security/update-googlebot-map.py (auto refreshed nightly)"
    print_status "Logs: /var/log/wp-security-nightly.log"
    echo
    print_status "To uninstall: sudo bash <(curl -s $RAW_URL/scripts/uninstall.sh)"
    echo
    print_status "For new websites: Re-run this script to protect them"
}

# Main function
main() {
    print_header "WordPress Security Direct Installation"
    print_status "This will install security rules to protect your WordPress sites"
    print_status "Repository: $REPO_URL"
    echo

    # Run checks
    check_root
    check_fastpanel
    ensure_dependencies

    # Install components
    install_googlebot_protection
    install_security_config
    backup_vhosts
    update_vhosts

    # Test and reload
    if test_nginx; then
        reload_nginx
        verify_installation
        setup_nightly_automation
        show_completion
    else
        print_error "Installation failed due to nginx configuration error"
        exit 1
    fi
}

# Run main function
main "$@"
