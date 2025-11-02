# WordPress Security with Nginx on FastPanel — Complete Guide for Newbies

A step-by-step, copy-paste friendly guide you can post for learners. It shows what we changed, why, and how to test. No prior deep Nginx knowledge required — follow the steps, read the explanations, and you'll understand what each command does.

## Overview (what we accomplish)

- Add a high-priority Nginx include file that blocks common WordPress attack surfaces (sensitive files, upload-PHP execution, hidden files, backup files, exploit patterns).
- Ensure that include is loaded before the broad location `~ \.php$` handler in every FastPanel-managed site so the blocking rules take effect.
- Provide small test scripts and commands so you can verify the site is protected and how to troubleshoot.

This guide is safe for FastPanel and uses the directory layout from the example server (paths like `/etc/nginx/fastpanel2-includes/` and `/etc/nginx/fastpanel2-sites/...`).

## Why this matters (plain language)

WordPress websites often have critical files in predictable locations (`wp-config.php`, `xmlrpc.php`, etc.) and allow file uploads. Attackers scan for these and try to:

- Download config files or read license/readme info.
- Upload PHP shells into `wp-content/uploads` and run them.
- Expose backup and log files containing credentials.

We use Nginx location rules to deny access to those things at the webserver level, so even if a file exists, it can't be executed or downloaded.

## Prerequisites

- SSH access as root or a user with sudo.
- Nginx & FastPanel installed.
- Site configs located under `/etc/nginx/fastpanel2-sites/` (the guide assumes this layout).
- You're comfortable running the provided shell commands (copy/paste).

## 🚀 Quick Start - 1 Command Setup

Run this single command on your VPS to install WordPress security:

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/hienhoceo-dpsmedia/WordPress-Security-with-Nginx-on-FastPanel/main/setup.sh)
```

That's it! The script will:
- ✅ Download all necessary files
- ✅ Install security rules for all your FastPanel sites
- ✅ Create automatic backups
- ✅ Test basic protections
- ✅ Provide next steps

### Quick Test
After installation, test your security:

```bash
curl -s https://raw.githubusercontent.com/hienhoceo-dpsmedia/WordPress-Security-with-Nginx-on-FastPanel/main/scripts/quick-test.sh | bash -s your-domain.com
```

---

## Traditional Setup (Clone Repository)

If you prefer to clone the repository first:

```bash
git clone https://github.com/hienhoceo-dpsmedia/WordPress-Security-with-Nginx-on-FastPanel.git
cd WordPress-Security-with-Nginx-on-FastPanel
sudo ./scripts/install.sh
```

## Detailed Installation Guide

### 1 — Create the Nginx security include file (one file for all sites)

Path: `/etc/nginx/fastpanel2-includes/wordpress-security.conf`

This file contains many location rules that deny access to sensitive items.

Command to create it (copy-paste):

```bash
sudo tee /etc/nginx/fastpanel2-includes/wordpress-security.conf >/dev/null <<'EOF'
# WordPress Security Configuration - High Priority Version
# File: /etc/nginx/fastpanel2-includes/wordpress-security.conf
# Uses exact match (=) and prefix match (^~) for highest priority

# ========== EXACT MATCH BLOCKS (HIGHEST PRIORITY) ==========
location = /xmlrpc.php { deny all; return 403; }
location = /wp-admin/install.php { deny all; return 403; }
location = /wp-admin/upgrade.php { deny all; return 403; }
location = /wp-content/debug.log { deny all; return 403; }
location = /readme.html { deny all; return 403; }
location = /license.txt { deny all; return 403; }
location = /wp-config.php { deny all; return 403; }
location = /wp-config-sample.php { deny all; return 403; }

# ========== PREFIX MATCH BLOCKS (HIGH PRIORITY) ==========
location ^~ /.git { deny all; return 403; }
location ^~ /.svn { deny all; return 403; }
location ^~ /.ht { deny all; return 403; }

# ========== REGEX BLOCKS (STILL HIGH PRIORITY FOR PHP) ==========
location ~* /wp-content/uploads/.*\.php$ { deny all; return 403; }
location ~* ^/wp-includes/.*\.php$ { deny all; return 403; }
location = /wp-includes/ms-files.php { }  # multisite exception
location ~* wp-config { deny all; return 403; }

# ========== BLOCK BACKUP & LOG FILES ==========
location ~* \.(bak|backup|old|orig|original|php~|php\.save|php\.bak|php#)$ { deny all; return 403; }
location ~* \.(log|sql|swp|swo)$ { deny all; return 403; }

# ========== BLOCK COMPRESSED ARCHIVES IN WP-CONTENT ==========
location ~* ^/wp-content/.*\.(zip|gz|tar|bzip2|7z|rar)$ { deny all; return 403; }

# ========== BLOCK FILES IN PLUGINS & THEMES ==========
location ~* ^/wp-content/plugins/.+\.(txt|log|md)$ { deny all; return 403; }
location ~* ^/wp-content/themes/.+\.(txt|log|md)$  { deny all; return 403; }

# ========== BLOCK HIDDEN FILES ==========
location ~* /\.user\.ini { deny all; return 403; }
location ~* /\. { deny all; return 403; }

# ========== BLOCK DANGEROUS SCRIPT TYPES ==========
location ~* \.(pl|cgi|py|sh|lua|asp|aspx|exe|dll)$ { deny all; return 403; }

# ========== BLOCK EXPLOIT FILES ==========
location ~* /(timthumb|thumb|thumbnail|phpinfo|webshell|shell|c99|r57|backdoor|evil|hack|mobiquo)\.php$ { deny all; return 403; }

# ========== BLOCK ATTACK PATTERNS ==========
location ~* "(eval\()" { deny all; return 403; }
location ~* "(base64_encode)(.*)(\()" { deny all; return 403; }
location ~* "(GLOBALS|REQUEST)(=|\[|%)" { deny all; return 403; }
location ~* "(<|%3C).*script.*(>|%3)" { deny all; return 403; }
location ~* "(\'|\")(.*)(drop|insert|md5|select|union)" { deny all; return 403; }
location ~* "(boot\.ini|etc/passwd|self/environ)" { deny all; return 403; }
location ~* "(127\.0\.0\.1)" { deny all; return 403; }
location ~* "([a-z0-9]{2000})" { deny all; return 403; }
location ~* "(javascript\:)(.*)(\;)" { deny all; return 403; }
EOF
```

Permissions (ensure readable by Nginx):

```bash
sudo chmod 644 /etc/nginx/fastpanel2-includes/wordpress-security.conf
```

**Explanation:**
This file contains many location rules. Exact matches (`location = /file`) take highest priority, prefix matches (`^~`) next, and regex `~*` rules are tested in the order Nginx sees them — so placement matters.

### 2 — Ensure the include is loaded early for all FastPanel sites

We must ensure `include /etc/nginx/fastpanel2-includes/*.conf;` is present in every vhost and placed before broad PHP handlers. The script below edits every vhost file under `/etc/nginx/fastpanel2-sites/`, removes duplicate includes, and inserts the include right after the `disable_symlinks` line (which is a safe place in FastPanel vhosts).

Run this (careful, it edits vhost configs — backups are created automatically):

```bash
# Backup all vhost configs first
sudo cp -a /etc/nginx/fastpanel2-sites /root/backup-fastpanel2-sites-$(date +%F_%T)

# For each vhost config, remove duplicates and insert the include after disable_symlinks
for vhost in /etc/nginx/fastpanel2-sites/*/*.conf; do
  echo "Updating $vhost"
  sudo sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"
  sudo sed -i '/disable_symlinks if_not_owner from=\$root_path;/a\    # load security includes early\n    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"
done

# Validate nginx and reload (only reload if syntax OK)
sudo nginx -t && sudo systemctl reload nginx
```

**Explanation:**

- `sed -i '/.../d'` removes any prior include lines to avoid duplicates.
- `sed -i '/disable_symlinks .../a\ ...'` appends the include right after the disable_symlinks line within the server block, so security rules are read before `location ~ \.php$` handlers.
- If you have a different vhost layout (not under `/etc/nginx/fastpanel2-sites/`), adjust the `for vhost in ...` path accordingly.

### 3 — Test the rules (quick checks + separate category scripts)

**Quick single test (small)**

```bash
curl -I https://your-domain.tld/wp-content/uploads/test-block.php
# Expect: HTTP/1.1 403 Forbidden
```

**Full combined test (one-liner)**

This runs a few important checks and prints HTTP codes:

```bash
bash -c 'echo "=== WordPress Security Test ===";
for url in wp-config.php xmlrpc.php wp-admin/install.php wp-admin/upgrade.php wp-content/uploads/test.php readme.html license.txt; do
  code=$(curl -s -o /dev/null -w "%{http_code}" https://your-domain.com/$url);
  printf "%-40s %s\n" "$url:" "$code";
done;
echo; for url in / /wp-admin/ /wp-login.php; do
  code=$(curl -s -o /dev/null -w "%{http_code}" https://your-domain.com$url);
  printf "%-40s %s\n" "$url:" "$code";
done; echo "=== Test Complete ==="'
```

(Replace `your-domain.com` with your domain.)

**Separate test files (recommended for repeated checks)**

The repository includes test scripts:

```bash
# Quick test
./scripts/quick-test.sh your-domain.com

# Comprehensive test
./scripts/test-security.sh your-domain.com

# Verbose output
./scripts/test-security.sh your-domain.com --verbose
```

**Expected output summary**

- Most security checks → 403 (blocked).
- Homepage `/` → 200 (OK).
- `/wp-admin/` → 302 (redirect) — normal.
- `/wp-login.php` → 200 or 302 depending on auth flow — normal.

### 4 — Verify include placement (confirm it's where we want it)

Find the include lines across sites:

```bash
sudo grep -n "fastpanel2-includes" /etc/nginx/fastpanel2-sites/*/*.conf
```

Show context for a single vhost (replace path as needed):

```bash
sudo sed -n '1,60p' /etc/nginx/fastpanel2-sites/your-site-d6ba/your-site.com.conf
```

Look for the include immediately after:

```
disable_symlinks if_not_owner from=$root_path;
```

If it is there and curl tests return 403 for uploaded PHP, you're good.

## Using the Repository Scripts

### Installation

```bash
# Clone and run
git clone https://github.com/yourusername/WordPress-Security-with-Nginx-on-FastPanel.git
cd WordPress-Security-with-Nginx-on-FastPanel
sudo ./scripts/install.sh
```

The install script:
- ✅ Creates backups of your existing configuration
- ✅ Installs the security include file
- ✅ Updates all vhost configurations
- ✅ Tests and reloads Nginx
- ✅ Verifies the installation

### Testing

```bash
# Quick test (essential checks only)
./scripts/quick-test.sh your-domain.com

# Comprehensive test
./scripts/test-security.sh your-domain.com

# With verbose output
./scripts/test-security.sh your-domain.com --verbose

# Skip CDN bypass tests
./scripts/test-security.sh your-domain.com --skip-cdn
```

### Uninstallation

```bash
# Remove all security rules
sudo ./scripts/uninstall.sh
```

The uninstall script:
- ✅ Creates backup before removing
- ✅ Removes security includes from all vhosts
- ✅ Removes the security configuration file
- ✅ Tests and reloads Nginx
- ✅ Verifies removal

## 5 — Common troubleshooting & explanation (newbie-friendly)

### A — Test returns 200 for a sensitive file

**Possible causes:**

1. The include wasn't loaded into the vhost where the domain points.
   - Check: `grep -R "fastpanel2-includes" /etc/nginx`
   - Ensure the domain's vhost config has the include.

2. A CDN (Cloudflare, etc.) returned a cached 200.
   - Bypass the CDN when testing: `curl -I --resolve your-domain.com:443:SERVER_IP https://your-domain.com/wp-config.php`

3. A conflicting location block earlier in the file overrides the rule.
   - Ensure include is placed before `location ~ \.php$` or add the upload-block directly above it.

### B — Nginx fails to reload

Run `sudo nginx -t` — read the error, fix the config, and retry. The sed scripts create backups; restore if needed.

### C — FastPanel resets config on update

FastPanel may rebuild vhosts from templates. To make changes durable:

1. Use the FastPanel UI to include custom includes if it provides a custom include area, or
2. Add the include insertion to `/etc/nginx/fastpanel2-sites/` (we modified those), and keep backups of `/etc/nginx/fastpanel2-sites/` and `/etc/nginx/fastpanel2-includes/`.

### D — Want to test origin (bypass CDN)

If your server IP is 1.2.3.4:

```bash
curl -I --resolve your-domain.com:443:1.2.3.4 https://your-domain.com/wp-config.php
```

## 6 — Extra recommended hardening (optional)

### Rate-limit wp-login.php

```nginx
limit_req_zone $binary_remote_addr zone=wp_login:10m rate=10r/m;

location = /wp-login.php {
    limit_req zone=wp_login burst=5 nodelay;
    # your php handling
}
```

### Security headers

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

### Fail2Ban

Create a jail for wp-login attempts (recommended if not already configured).

### File system

Keep `wp-config.php` readable only by owner; consider moving it one dir above webroot if WordPress and code allow.

## 7 — Rollback & backups (safety)

The scripts create automatic backups. To restore manually:

### Restore vhost backup

```bash
sudo cp /root/backup-fastpanel2-sites-YYYY-MM-DD_HH:MM:SS/<site> /etc/nginx/fastpanel2-sites/<site>.conf
sudo nginx -t && sudo systemctl reload nginx
```

### Or restore a specific vhost backup file

```bash
sudo cp /etc/nginx/fastpanel2-sites/your-site-d6ba/your-site.com.conf.bak.YYYY_MM_DD_HHMM /etc/nginx/fastpanel2-sites/your-site-d6ba/your-site.com.conf
sudo nginx -t && sudo systemctl reload nginx
```

## 8 — Quick checklist for posting to newbies (copyable)

1. ✅ Create `wordpress-security.conf` in `/etc/nginx/fastpanel2-includes/` (provided).
2. ✅ Insert `include /etc/nginx/fastpanel2-includes/*.conf;` into each vhost right after `disable_symlinks if_not_owner from=$root_path;`.
3. ✅ Test by requesting `https://your-domain/wp-content/uploads/test.php` and other sensitive files. Expect 403 for blocked items and 200/302 for normal pages.
4. ✅ If any sensitive file shows 200, verify CDN caching and vhost include placement.

## 9 — Complete sample commands (one block)

If you want to run everything at once (creates include, inserts into all vhosts, reloads nginx):

```bash
# Create include (overwrites existing)
sudo tee /etc/nginx/fastpanel2-includes/wordpress-security.conf >/dev/null <<'EOF'
# (full content — same as in Step 1)
EOF
sudo chmod 644 /etc/nginx/fastpanel2-includes/wordpress-security.conf

# Backup vhosts and insert includes for all sites
sudo cp -a /etc/nginx/fastpanel2-sites /root/backup-fastpanel2-sites-$(date +%F_%T)
for vhost in /etc/nginx/fastpanel2-sites/*/*.conf; do
  sudo sed -i '/include \/etc\/nginx\/fastpanel2-includes\/\*\.conf;/d' "$vhost"
  sudo sed -i '/disable_symlinks if_not_owner from=\$root_path;/a\    include /etc/nginx/fastpanel2-includes/*.conf;' "$vhost"
done

# test & reload
sudo nginx -t && sudo systemctl reload nginx
```

(If you'll actually run this, copy the exact Step-1 file content into the EOF block.)

## Final words — friendly notes

This guide was written for FastPanel layouts and tested in that environment. If your panel or hosting uses different paths, adjust the `/etc/nginx/fastpanel2-sites/` and `/etc/nginx/fastpanel2-includes/` paths accordingly.

The approach defends at the webserver level — even if a vulnerable plugin lets someone upload a file, the Nginx rules prevent it from being executed or downloaded.

Keep a backup of your configs before making changes — we made backups in the examples, and you should too.

## Repository Structure

```
WordPress-Security-with-Nginx-on-FastPanel/
├── README.md                          # This file
├── setup.sh                           # 🚀 1-command setup script
├── nginx-includes/
│   └── wordpress-security.conf        # Main security configuration
└── scripts/
    ├── install.sh                     # Automated installation script
    ├── uninstall.sh                   # Automated uninstallation script
    ├── test-security.sh               # Comprehensive security testing
    └── quick-test.sh                  # Quick security checks
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - feel free to use and modify for your needs.