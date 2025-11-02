#!/bin/bash

# Quick WordPress Security Test
# Simple test to verify basic security protections are working

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default domain
DOMAIN="${1:-}"
USER_AGENT="Mozilla/5.0 (WordPress Security Audit)"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_header() {
    echo
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check domain argument
if [[ -z "$DOMAIN" ]]; then
    echo "Quick WordPress Security Test"
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

print_status "Quick WordPress Security Test for $DOMAIN"
print_status "Testing basic security protections..."
echo

# Quick tests - most critical security checks
print_header "Critical Security Tests"

# Helper to fetch HTTP status code
get_status() {
    local url="$1"
    local status

    status=$(curl -sS -o /dev/null -w "%{http_code}" -A "$USER_AGENT" "$url" 2>/dev/null || true)
    status=${status//$'\r'/}
    if [[ -z "${status// }" ]]; then
        status="000"
    fi
    echo "$status"
}

# Test PHP execution in uploads
response=$(get_status "https://$DOMAIN/wp-content/uploads/test.php")
    if [[ "$response" == "403" ]]; then
        print_success "PHP execution blocked in uploads - HTTP $response ✓"
    elif [[ "$response" == "000" ]]; then
        print_warning "PHP execution check inconclusive (network error) ⚠"
    else
        print_error "PHP execution not blocked in uploads - HTTP $response ✗"
    fi

# Test wp-config access
response=$(get_status "https://$DOMAIN/wp-config.php")
if [[ "$response" == "403" ]]; then
    print_success "wp-config.php access blocked - HTTP $response ✓"
elif [[ "$response" == "000" ]]; then
    print_warning "wp-config.php check inconclusive (network error) ⚠"
else
    print_error "wp-config.php access not blocked - HTTP $response ✗"
fi

# Test xmlrpc.php access
response=$(get_status "https://$DOMAIN/xmlrpc.php")
if [[ "$response" == "403" ]]; then
    print_success "xmlrpc.php access blocked - HTTP $response ✓"
elif [[ "$response" == "000" ]]; then
    print_warning "xmlrpc.php check inconclusive (network error) ⚠"
else
    print_error "xmlrpc.php access not blocked - HTTP $response ✗"
fi

# Test readme.html access
response=$(get_status "https://$DOMAIN/readme.html")
if [[ "$response" == "403" ]]; then
    print_success "readme.html access blocked - HTTP $response ✓"
elif [[ "$response" == "000" ]]; then
    print_warning "readme.html check inconclusive (network error) ⚠"
else
    print_error "readme.html access not blocked - HTTP $response ✗"
fi

print_header "Normal Functionality Tests"

# Test normal functionality
response=$(get_status "https://$DOMAIN/")
if [[ "$response" == "200" ]]; then
    print_success "Homepage accessible - HTTP $response ✓"
else
    print_error "Homepage not accessible - HTTP $response ✗"
fi

response=$(get_status "https://$DOMAIN/wp-admin/")
if [[ "$response" == "302" || "$response" == "200" ]]; then
    print_success "WP Admin accessible - HTTP $response ✓"
else
    print_error "WP Admin not accessible - HTTP $response ✗"
fi

echo
print_status "Quick test completed!"
print_status "For detailed testing, run: ./scripts/test-security.sh $DOMAIN"
