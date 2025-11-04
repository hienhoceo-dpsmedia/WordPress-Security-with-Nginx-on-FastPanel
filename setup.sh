#!/bin/bash

# WordPress Security One-Command Setup for FastPanel
# Just run this command on your VPS:
# bash <(curl -s https://raw.githubusercontent.com/hienhoceo-dpsmedia/WordPress-Security-with-Nginx-on-FastPanel/main/setup.sh)

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

# Repository information
REPO_URL="https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel"
RAW_URL="https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        print_status "Try: wget -qO- $RAW_URL/install-direct.sh | sudo bash"
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

# Run direct installation
run_installation() {
    print_header "Starting WordPress Security Installation"

    # Download and run direct installation script
    wget -qO- "$RAW_URL/install-direct.sh" | bash

    print_success "Installation completed!"
}

# Offer to run full test
offer_test() {
    echo
    print_header "Security Test"
    print_status "Would you like to run the comprehensive security test on your domains?"
    print_status "This verifies all protection rules (sensitive files, uploads, exploits, etc.)."
    echo

    read -p "Run security test? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Enter your domain name(s) to test (space-separated, or press Enter to skip):"
        read -p "Domains: " domains

        if [[ -n "$domains" ]]; then
            for domain in $domains; do
                print_status "Testing $domain..."
                wget -qO- "$RAW_URL/scripts/test-security.sh" | bash -s "$domain"
                echo
            done
        else
            print_warning "No domains provided. You can run tests later:"
            print_status "wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/scripts/test-security.sh | bash -s your-domain.com"
        fi
    fi
}

# Show completion message
show_completion() {
    print_header "Setup Complete!"
    echo
    print_success "✅ WordPress security rules have been installed"
    print_success "✅ All FastPanel sites are now protected"
    print_success "✅ Automatic backups were created"
    echo
    print_status "What was installed:"
    echo "  • Nginx security rules to block common WordPress attacks"
    echo "  • PHP execution protection in uploads directory"
    echo "  • Sensitive file access blocking"
    echo "  • Backup and development file protection"
    echo "  • Known exploit pattern blocking"
    echo
    print_status "Next steps:"
    echo "1. Test your security: curl -s https://raw.githubusercontent.com/hienhoceo-dpsmedia/WordPress-Security-with-Nginx-on-FastPanel/main/scripts/test-security.sh | bash -s your-domain.com"
    echo "2. Monitor your Nginx logs for blocked attacks"
    echo
    print_status "Backup location: /root/backup-fastpanel2-sites-YYYY-MM-DD_HH:MM:SS"
    print_status "Repository: $REPO_URL"
    echo
    print_status "To uninstall: sudo bash <(curl -s https://raw.githubusercontent.com/hienhoceo-dpsmedia/WordPress-Security-with-Nginx-on-FastPanel/main/scripts/uninstall.sh)"
}

# Cleanup temporary files
cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Error handling
handle_error() {
    print_error "Setup failed. Please check the error messages above."
    print_status "You can try manual installation from: $REPO_URL"
    cleanup
    exit 1
}

# Main setup function
main() {
    print_header "WordPress Security Setup for FastPanel"
    print_status "This will install security rules to protect your WordPress sites"
    print_status "Repository: $REPO_URL"
    echo

    # Set error handling
    trap handle_error ERR
    trap cleanup EXIT

    # Run checks
    check_root
    check_fastpanel

    # Download and install
    run_installation

    # Offer testing
    offer_test

    # Show completion message
    show_completion
}

# Run main function
main "$@"
