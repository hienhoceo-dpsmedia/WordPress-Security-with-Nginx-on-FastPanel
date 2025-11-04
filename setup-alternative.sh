#!/bin/bash

# WordPress Security Setup - Alternative Methods
# Use this if the main setup command fails

set -euo pipefail

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
JSDELIVR_URL="https://cdn.jsdelivr.net/gh/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel@master"

# Test different download methods
test_download_method() {
    local method="$1"
    local url="$2"

    print_status "Testing $method..."

    case $method in
        "curl")
            if curl -s --connect-timeout 10 "$url" >/dev/null 2>&1; then
                return 0
            fi
            ;;
        "wget")
            if wget -q --timeout=10 --tries=1 "$url" >/dev/null 2>&1; then
                return 0
            fi
            ;;
        "jsdelivr")
            if curl -s --connect-timeout 10 "$url" >/dev/null 2>&1; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Try different download methods
try_download_methods() {
    print_header "Testing Download Methods"

    # Test methods
    if test_download_method "curl" "$RAW_URL/setup.sh"; then
        print_success "Direct curl works"
        echo "sudo bash <(curl -s $RAW_URL/setup.sh)"
        return 0
    fi

    if test_download_method "wget" "$RAW_URL/setup.sh"; then
        print_success "wget works"
        echo "sudo bash <(wget -qO- $RAW_URL/setup.sh)"
        return 0
    fi

    if test_download_method "jsdelivr" "$JSDELIVR_URL/setup.sh"; then
        print_success "jsdelivr CDN works"
        echo "sudo bash <(curl -s $JSDELIVR_URL/setup.sh)"
        return 0
    fi

    print_error "All download methods failed"
    return 1
}

# Manual download instructions
show_manual_instructions() {
    print_header "Manual Installation Instructions"

    echo "If automatic download doesn't work, follow these steps:"
    echo
    echo "1. Download files manually:"
    echo "   curl -O $RAW_URL/nginx-includes/wordpress-security.conf"
    echo "   curl -O $RAW_URL/scripts/install.sh"
    echo "   chmod +x install.sh"
    echo
    echo "2. Create the directory structure:"
    echo "   sudo mkdir -p /etc/nginx/fastpanel2-includes"
    echo "   sudo mv wordpress-security.conf /etc/nginx/fastpanel2-includes/"
    echo "   sudo chmod 644 /etc/nginx/fastpanel2-includes/wordpress-security.conf"
    echo
    echo "3. Run installation:"
    echo "   sudo ./install.sh"
    echo
    echo "4. Test your setup:"
    echo "   curl -s $RAW_URL/scripts/test-security.sh | bash -s your-domain.com"
}

# Check network connectivity
check_connectivity() {
    print_status "Checking network connectivity..."

    # Test GitHub connectivity
    if ping -c 1 github.com >/dev/null 2>&1; then
        print_success "GitHub is reachable"
    else
        print_error "Cannot reach GitHub"
        return 1
    fi

    # Test DNS resolution
    if nslookup raw.githubusercontent.com >/dev/null 2>&1; then
        print_success "DNS resolution works"
    else
        print_error "DNS resolution failed"
        return 1
    fi
}

# Main function
main() {
    print_header "WordPress Security Setup - Alternative Methods"

    # Check connectivity
    if ! check_connectivity; then
        print_error "Network connectivity issues detected"
        show_manual_instructions
        exit 1
    fi

    # Try download methods
    if try_download_methods; then
        print_success "Found working download method above"
    else
        print_error "All automatic methods failed"
        show_manual_instructions
        exit 1
    fi
}

main "$@"
