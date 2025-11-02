#!/bin/bash

# WordPress Security Direct Installation Script
# Combined installation - download config and update vhosts in one script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Repository URLs
REPO_URL="https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel"
RAW_URL="https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master"

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

# Download and install security configuration
install_security_config() {
    print_header "Installing WordPress Security Configuration"

    # Create nginx includes directory if it doesn't exist
    mkdir -p /etc/nginx/fastpanel2-includes
    print_success "Created /etc/nginx/fastpanel2-includes"

    # Download the security configuration
    print_status "Downloading security configuration..."
    if curl -s -o /etc/nginx/fastpanel2-includes/wordpress-security.conf "$RAW_URL/nginx-includes/wordpress-security.conf"; then
        print_success "Security configuration downloaded successfully"
    else
        print_error "Failed to download security configuration"
        exit 1
    fi

    # Set proper permissions
    chmod 644 /etc/nginx/fastpanel2-includes/wordpress-security.conf
    print_success "Set permissions on security configuration"
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

    # Count total vhost files
    for vhost in /etc/nginx/fastpanel2-sites/*/*.conf; do
        if [[ -f "$vhost" ]]; then
            ((total++))
        fi
    done

    if [[ $total -eq 0 ]]; then
        print_warning "No vhost configuration files found in /etc/nginx/fastpanel2-sites/"
        return 0
    fi

    print_status "Found $total vhost configuration(s) to update"

    # Update each vhost configuration
    for vhost in /etc/nginx/fastpanel2-sites/*/*.conf; do
        if [[ -f "$vhost" ]]; then
            print_status "Processing: $(basename "$vhost")"

            # Remove any existing include lines to avoid duplicates
            sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"

            # Check if disable_symlinks line exists and insert include after it
            if grep -q "disable_symlinks if_not_owner from=\$root_path;" "$vhost"; then
                sed -i '/disable_symlinks if_not_owner from=\$root_path;/a\    # load security includes early\n    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"
                ((count++))
                print_success "✓ Added security include to $(basename "$vhost")"
            else
                print_warning "⚠ Could not find disable_symlinks directive in $(basename "$vhost")"
                print_status "  You may need to manually add the include line to this file"
            fi
        fi
    done

    print_success "Updated $count out of $total vhost configuration(s)"
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

    # Check if security include exists
    if [[ -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        print_success "✓ Security include file exists"
    else
        print_error "✗ Security include file missing"
        return 1
    fi

    # Check if vhosts include the security config
    local includes_found=0
    for vhost in /etc/nginx/fastpanel2-sites/*/*.conf; do
        if [[ -f "$vhost" ]] && grep -q "fastpanel2-includes" "$vhost"; then
            ((includes_found++))
        fi
    done

    if [[ $includes_found -gt 0 ]]; then
        print_success "✓ Security include found in $includes_found vhost configuration(s)"
    else
        print_warning "⚠ Security include not found in any vhost configuration"
        print_status "  You may need to manually add the include to your vhost files"
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
    echo
    print_status "Next steps:"
    echo "1. Test your security: curl -s $RAW_URL/scripts/quick-test.sh | bash -s your-domain.com"
    echo "2. Monitor your Nginx logs for blocked attacks"
    echo "3. For comprehensive testing: curl -s $RAW_URL/scripts/test-security.sh | bash -s your-domain.com"
    echo
    print_status "Backup location: $BACKUP_DIR"
    print_status "Repository: $REPO_URL"
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

    # Install components
    install_security_config
    backup_vhosts
    update_vhosts

    # Test and reload
    if test_nginx; then
        reload_nginx
        verify_installation
        show_completion
    else
        print_error "Installation failed due to nginx configuration error"
        exit 1
    fi
}

# Run main function
main "$@"