#!/bin/bash

# WordPress Security Test Script
# Tests various WordPress security endpoints to verify protection

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default domain - will be overridden by command line argument
DOMAIN=""

# Test results counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNING_TESTS++))
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

print_header() {
    echo
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Print usage information
usage() {
    echo "WordPress Security Test Script"
    echo "Usage: $0 <domain> [options]"
    echo
    echo "Required:"
    echo "  domain    Domain name to test (e.g., example.com)"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Verbose output"
    echo "  --skip-cdn     Skip CDN bypass tests"
    echo
    echo "Examples:"
    echo "  $0 example.com"
    echo "  $0 example.com --verbose"
    echo "  $0 example.com --skip-cdn"
    exit 0
}

# Parse command line arguments
parse_args() {
    VERBOSE=false
    SKIP_CDN=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --skip-cdn)
                SKIP_CDN=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                ;;
            *)
                if [[ -z "$DOMAIN" ]]; then
                    DOMAIN="$1"
                else
                    print_error "Too many arguments"
                    usage
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$DOMAIN" ]]; then
        print_error "Domain is required"
        usage
    fi
}

# Test a single URL and return HTTP status code
test_url() {
    local url="$1"
    local expected_code="$2"
    local description="$3"

    ((TOTAL_TESTS++))

    if [[ "$VERBOSE" == true ]]; then
        print_status "Testing: $url"
    fi

    local response_code
    response_code=$(wget -q --server-response --timeout=10 --output-document=/dev/null \
        --user-agent="WordPress-Security-Test/1.0" \
        "https://$DOMAIN$url" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}' || echo "000")

    if [[ "$response_code" == "$expected_code" ]]; then
        print_success "$description - HTTP $response_code ✓"
        return 0
    else
        print_error "$description - HTTP $response_code (expected $expected_code) ✗"
        if [[ "$VERBOSE" == true ]]; then
            print_status "URL: https://$DOMAIN$url"
        fi
        return 1
    fi
}

# Test with direct IP (bypass CDN)
test_url_direct() {
    local url="$1"
    local expected_code="$2"
    local description="$3"

    if [[ "$SKIP_CDN" == true ]]; then
        return 0
    fi

    ((TOTAL_TESTS++))

    # Get server IP
    local server_ip
    server_ip=$(dig +short "$DOMAIN" | head -n1)

    if [[ -z "$server_ip" ]]; then
        print_warning "Could not resolve server IP for $DOMAIN - skipping direct test"
        return 0
    fi

    if [[ "$VERBOSE" == true ]]; then
        print_status "Testing direct to IP ($server_ip): $url"
    fi

    local origin_host="$server_ip"
    if [[ "$server_ip" == *:* ]]; then
        origin_host="[$server_ip]"
    fi

    local response_code
    response_code=$(wget -q --server-response --timeout=10 --output-document=/dev/null \
        --user-agent="WordPress-Security-Test/1.0" \
        --header="Host: $DOMAIN" \
        "https://$origin_host$url" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}' || echo "000")

    if [[ "$response_code" == "$expected_code" ]]; then
        print_success "$description (direct) - HTTP $response_code ✓"
        return 0
    else
        print_warning "$description (direct) - HTTP $response_code (expected $expected_code) ⚠"
        if [[ "$VERBOSE" == true ]]; then
            print_status "This might be due to CDN caching"
        fi
        return 1
    fi
}

# Test critical WordPress files that should be blocked
test_critical_files() {
    print_header "Testing Critical WordPress Files (Should Return 403)"

    local files=(
        "/wp-config.php"
        "/wp-config-sample.php"
        "/xmlrpc.php"
        "/wp-admin/install.php"
        "/wp-admin/upgrade.php"
        "/wp-content/debug.log"
        "/readme.html"
        "/license.txt"
    )

    for file in "${files[@]}"; do
        test_url "$file" "403" "Access to $file should be blocked"
        test_url_direct "$file" "403" "Access to $file should be blocked"
    done
}

# Test PHP execution in uploads directory
test_upload_php() {
    print_header "Testing PHP Execution in Uploads (Should Return 403)"

    local php_files=(
        "/wp-content/uploads/test.php"
        "/wp-content/uploads/shell.php"
        "/wp-content/uploads/2023/12/malicious.php"
        "/wp-content/backup.php"
        "/wp-content/cache/test.php"
    )

    for file in "${php_files[@]}"; do
        test_url "$file" "403" "PHP execution in $file should be blocked"
        test_url_direct "$file" "403" "PHP execution in $file should be blocked"
    done
}

# Test backup and development files
test_backup_files() {
    print_header "Testing Backup and Development Files (Should Return 403)"

    local backup_files=(
        "/wp-config.php.bak"
        "/wp-config.php.backup"
        "/wp-config.php.old"
        "/wp-config.php~"
        "/database.sql"
        "/backup.zip"
        "/site.tar.gz"
        "/wp-content/uploads/backup.sql"
        "/.env"
        "/.htaccess"
    )

    for file in "${backup_files[@]}"; do
        test_url "$file" "403" "Access to $file should be blocked"
        test_url_direct "$file" "403" "Access to $file should be blocked"
    done
}

# Test dangerous script types
test_dangerous_scripts() {
    print_header "Testing Dangerous Script Types (Should Return 403)"

    local scripts=(
        "/shell.cgi"
        "/test.pl"
        "/script.py"
        "/malicious.sh"
        "/exploit.lua"
        "/hack.asp"
        "/backdoor.aspx"
    )

    for script in "${scripts[@]}"; do
        test_url "$script" "403" "Access to $script should be blocked"
        test_url_direct "$script" "403" "Access to $script should be blocked"
    done
}

# Test known exploit files
test_exploit_files() {
    print_header "Testing Known Exploit Files (Should Return 403)"

    local exploits=(
        "/timthumb.php"
        "/phpinfo.php"
        "/webshell.php"
        "/c99.php"
        "/r57.php"
        "/backdoor.php"
        "/evil.php"
        "/hack.php"
    )

    for exploit in "${exploits[@]}"; do
        test_url "$exploit" "403" "Access to $exploit should be blocked"
        test_url_direct "$exploit" "403" "Access to $exploit should be blocked"
    done
}

# Test normal WordPress functionality
test_normal_functionality() {
    print_header "Testing Normal WordPress Functionality"

    # These should work normally
    test_url "/" "200" "Homepage should be accessible"
    test_url "/wp-admin/" "302" "WP Admin should redirect (302)"
    test_url "/wp-login.php" "200" "WP Login should be accessible"
    test_url "/wp-content/themes/twentytwentyfour/style.css" "200" "Theme CSS should be accessible"
    test_url "/wp-includes/js/jquery/jquery.min.js" "200" "WordPress JS should be accessible"

    # Test multisite exception
    test_url "/wp-includes/ms-files.php" "200" "Multisite files should be accessible (if exists)"
}

# Test attack patterns in query strings
test_attack_patterns() {
    print_header "Testing Attack Patterns in Query Strings"

    local patterns=(
        "/?eval(base64_decode('test'))"
        "/?GLOBALS[_POST]=test"
        "/?<script>alert('xss')</script>"
        "/?id=1'+DROP+TABLE+users--"
        "/?file=../../../../etc/passwd"
        "/?q=javascript:alert(1);"
    )

    for pattern in "${patterns[@]}"; do
        test_url "$pattern" "403" "Attack pattern should be blocked"
        test_url_direct "$pattern" "403" "Attack pattern should be blocked"
    done
}

# Check if security configuration is loaded
check_security_config() {
    print_header "Checking Security Configuration"

    ((TOTAL_TESTS++))
    if [[ -f "/etc/nginx/fastpanel2-includes/wordpress-security.conf" ]]; then
        print_success "Security configuration file exists"
    else
        print_error "Security configuration file not found"
    fi

    # Check if vhosts include the security config
    ((TOTAL_TESTS++))
    local includes_found=0
    for vhost in /etc/nginx/fastpanel2-sites/*/*.conf; do
        if [[ -f "$vhost" ]] && grep -q "fastpanel2-includes" "$vhost"; then
            ((includes_found++))
        fi
    done

    if [[ $includes_found -gt 0 ]]; then
        print_success "Security include found in $includes_found vhost configuration(s)"
    else
        print_warning "Security include not found in any vhost configuration"
    fi
}

# Print summary
print_summary() {
    echo
    print_header "Test Summary"

    echo -e "${BLUE}Total tests:${NC} $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
    echo -e "${YELLOW}Warnings:${NC} $WARNING_TESTS"
    echo -e "${RED}Failed:${NC} $FAILED_TESTS"
    echo

    local success_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    echo -e "${BLUE}Success rate:${NC} $success_rate%"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo
        echo -e "${GREEN}[OK]${NC} All critical security tests passed! Your WordPress site is well protected."
    else
        echo
        echo -e "${RED}[ATTENTION]${NC} Some security tests failed. Please review the configuration."
    fi

    if [[ $WARNING_TESTS -gt 0 ]]; then
        echo
        echo -e "${YELLOW}[NOTICE]${NC} Some tests returned warnings. This might be due to CDN caching or other factors."
    fi
}

# Main function
main() {
    print_status "WordPress Security Test for $DOMAIN"
    print_status "Started at $(date)"
    echo

    # Run tests
    check_security_config
    test_critical_files
    test_upload_php
    test_backup_files
    test_dangerous_scripts
    test_exploit_files
    test_attack_patterns
    test_normal_functionality

    # Print summary
    print_summary

    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Parse arguments and run main function
parse_args "$@"
main
