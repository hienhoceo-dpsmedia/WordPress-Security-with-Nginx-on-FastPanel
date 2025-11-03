# 🛡️ WordPress Security with Nginx on FastPanel

<div align="center">

[![Security](https://img.shields.io/badge/Security-Hardening-green?style=for-the-badge&logo=security)](https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel)
[![WordPress](https://img.shields.io/badge/WordPress-Protection-blue?style=for-the-badge&logo=wordpress)](https://wordpress.org)
[![Nginx](https://img.shields.io/badge/Nginx-Web%20Server-009639?style=for-the-badge&logo=nginx)](https://nginx.org)
[![FastPanel](https://img.shields.io/badge/FastPanel-Hosting%20Panel-orange?style=for-the-badge)](https://fastpanel.direct)
[![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel?style=for-the-badge&logo=github&color=yellow)](https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/stargazers)

**🚀 One-command WordPress security hardening for FastPanel servers**

A step-by-step, copy-paste friendly guide that protects WordPress sites at the Nginx level. No prior deep Nginx knowledge required — follow the steps, read the explanations, and you'll understand what each command does.

[⭐ **Give us a star**](https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel) if this helps you! | [🚀 **Quick Start**(#-quick-start---1-command-setup-recommended)

</div>

## ✨ Features

- 🛡️ **Comprehensive Protection** - Blocks PHP execution in uploads, sensitive file access, backup files, and known exploit patterns
- 🚀 **One-Command Setup** - Install security rules for all WordPress sites with a single command
- 🔄 **Automatic Updates** - Nightly cron job protects new websites automatically
- ✅ **Built-in Testing** - Comprehensive security test scripts included
- 📋 **Beginner Friendly** - Copy-paste commands with detailed explanations
- 🔧 **FastPanel Optimized** - Specifically designed for FastPanel's directory structure
- 📊 **Progress Tracking** - Visual progress indicators during installation
- 🗂️ **Smart Backups** - Automatic backups before any changes
- 🤖 **Bot Verification** - Rejects fake Googlebot crawlers by validating official IP ranges

## 🎯 What This Protects Against

| Threat Type | How We Block It |
|-------------|-----------------|
| **PHP Shell Uploads** | Prevents PHP execution in `/wp-content/uploads/` |
| **Config File Access** | Blocks direct access to `wp-config.php`, `.env`, etc. |
| **Backup File Exposure** | Denies access to `.bak`, `.backup`, `.sql`, `.tar.gz` files |
| **Known Exploits** | Blocks common exploit files like `timthumb.php`, `webshell.php` |
| **Attack Patterns** | Filters malicious query strings and attack signatures |
| **Hidden Files** | Prevents access to `.git`, `.svn`, `.htaccess` files |
| **Dangerous Scripts** | Blocks execution of `.cgi`, `.pl`, `.py`, `.sh` files |
| **Fake Googlebot Crawlers** | Verifies Googlebot user agents against Google's published IP ranges |

## 🚀 Quick Demo

```bash
# Install security for all WordPress sites
wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/install-direct.sh | sudo bash

# Test protections
wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/scripts/quick-test.sh | bash -s your-domain.com
```

**Expected Results:**
- ✅ PHP execution in uploads → **HTTP 403 Forbidden**
- ✅ wp-config.php access → **HTTP 403 Forbidden**
- ✅ xmlrpc.php access → **HTTP 403 Forbidden**
- ✅ Normal pages → **HTTP 200 OK**

## 📋 Overview (what we accomplish)

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

## 📊 Security Impact

| Protection Type | Files/Paths Blocked | Risk Mitigation |
|-----------------|-------------------|-----------------|
| **Config Files** | `wp-config.php`, `.env`, `xmlrpc.php` | 🔴 High - Prevents credential exposure |
| **Upload Security** | `*.php` in `/wp-content/uploads/` | 🔴 High - Stops shell uploads |
| **Backup Files** | `*.bak`, `*.sql`, `*.tar.gz` | 🟡 Medium - Prevents data leaks |
| **Development Files** | `readme.html`, `license.txt` | 🟢 Low - Reduces information disclosure |
| **Known Exploits** | `timthumb.php`, `webshell.php` | 🔴 High - Blocks common attacks |
| **Attack Patterns** | SQL injection, XSS patterns | 🔴 High - Filters malicious requests |
| **Fake Googlebot Crawlers** | Validates User-Agent + IP against Google's published ranges | 🔴 High - Stops malicious crawlers posing as Google |

**🛡️ Total Coverage:** 20+ attack vectors blocked at the webserver level

## 🕷️ Googlebot Verification (New)

Bad actors often spoof the `Googlebot` user agent to bypass allowlists or rate limits.  
The installer now validates every Googlebot request by combining two signals:

- A managed `map` of official Googlebot IPv4/IPv6 ranges fetched from Google's public JSON endpoint.
- A curated list of Googlebot user agents (Search, AdsBot, InspectionTool, etc.).

If the user agent claims to be Googlebot but the source IP is not in Google's published ranges, the request is blocked immediately with **HTTP 403**.  
Fresh ranges are downloaded nightly by `/usr/local/share/wp-security/update-googlebot-map.py` and written to:

- `/etc/nginx/fastpanel2-includes/googlebot-verify-http.conf` — `map` definitions loaded in the global `http {}` block.
- `/etc/nginx/fastpanel2-includes/googlebot-verified.map` — the CIDR list used by the `map`.

Need an ad-hoc refresh?

```bash
sudo python3 /usr/local/share/wp-security/update-googlebot-map.py
sudo nginx -t && sudo systemctl reload nginx
```

### 🧪 How to Test Googlebot Blocking

1. Refresh the CIDR data (optional but recommended before testing):

   ```bash
   sudo python3 /usr/local/share/wp-security/update-googlebot-map.py
   sudo nginx -t && sudo systemctl reload nginx
   ```

2. From any non-Google IP, spoof the Googlebot user agent:

   ```bash
   curl -I -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" https://your-domain.com/
   ```

   Because the source IP is unverified, the response should be `HTTP/1.1 403 Forbidden`.

3. Inspect `/var/log/nginx/access.log` and confirm the entry shows status `403` for the spoofed request while legitimate Googlebot traffic continues to receive `200`.

## Prerequisites

- SSH access as root or a user with sudo.
- Nginx & FastPanel installed.
- Site configs located under `/etc/nginx/fastpanel2-sites/` (the guide assumes this layout).
- You're comfortable running the provided shell commands (copy/paste).

## 🚀 Quick Start - 1 Command Setup (Recommended)

Run this single command on your VPS to install WordPress security:

```bash
wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/install-direct.sh | sudo bash
```

That's it! The script will:
- ✅ Download all necessary files
- ✅ Install security rules for all your FastPanel sites
- ✅ Create automatic backups
- ✅ Test basic protections
- ✅ Set up a nightly cron job that runs a local vhost refresher (02:30) and prunes backups older than 7 days, so new FastPanel sites get protected automatically
- ✅ Provide next steps

### Quick Test
After installation, test your security:

```bash
wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/scripts/quick-test.sh | bash -s your-domain.com
```

---

## Traditional Setup (Clone Repository)

If you prefer to clone the repository first:

```bash
git clone https://github.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel.git
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
find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 | \
while IFS= read -r -d '' vhost; do
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
- The `find` command works whether FastPanel stores vhosts directly in `/etc/nginx/fastpanel2-sites/` or in child directories. Update the base path if your panel uses a custom location.

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
find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 | \
xargs -0 sudo grep -n "fastpanel2-includes"
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
- ✅ Installs `/usr/local/sbin/wp-security-nightly.sh` (wrapper for `/usr/local/share/wp-security/update-vhosts-nightly.sh`) and a cron entry (`30 2 * * *`) so the rules are re-applied nightly and old backups are rotated

Nightly automation logs to `/var/log/wp-security-nightly.log`. Adjust the schedule with `sudo crontab -e` if you prefer a different time or disable it by removing the cron line. The cron task calls the local updater script, so no nightly downloads are performed.
### Testing

```bash
# Quick test (essential checks only)
./scripts/quick-test.sh your-domain.com

# Comprehensive test
./scripts/test-security.sh your-domain.com

# With verbose output
./scripts/test-security.sh your-domain.com --verbose

# Skip CDN bypass tests (stay behind Cloudflare or similar)
./scripts/test-security.sh your-domain.com --skip-cdn

# Run without creating temporary fixtures
./scripts/test-security.sh your-domain.com --no-fixtures
```

> ℹ️ The comprehensive test now creates temporary “bait” files in your document root (backups, shells, etc.) so the Nginx rules can return real 403 responses. They are removed automatically when the script exits. Use `--no-fixtures` if you prefer to skip creating those files.

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
find /etc/nginx/fastpanel2-sites -type f -name '*.conf' -print0 | \
while IFS= read -r -d '' vhost; do
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

## Troubleshooting

### Alternative Installation Methods

If the recommended wget method fails, try these alternatives:

#### **Method 1: Download and run separately (Most Reliable)**
```bash
# Download the installation script
wget https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/install-direct.sh
# Make it executable
chmod +x install-direct.sh
# Run it
sudo ./install-direct.sh
```

#### **Method 2: Process substitution (may not work on some systems)**
```bash
sudo bash <(wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/install-direct.sh)
```

#### **Method 3: Use CDN alternative**
```bash
wget -qO- https://cdn.jsdelivr.net/gh/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel@master/install-direct.sh | sudo bash
```

#### **Method 4: Test connectivity**
```bash
# Test if GitHub is accessible
wget --spider https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/install-direct.sh
```

### Handling New Websites

The installer creates a nightly cron job that calls the local updater (`/usr/local/sbin/wp-security-nightly.sh` → `/usr/local/share/wp-security/update-vhosts-nightly.sh`) at 02:30. Any new FastPanel site you add today will be picked up automatically tonight without re-downloading the installer.

Need instant coverage (or disabled the cron job)? Just rerun:

```bash
wget -qO- https://raw.githubusercontent.com/hienhoceo-dpsmedia/wordpress-security-with-nginx-on-fastpanel/master/install-direct.sh | sudo bash
```

The script is **safe to run multiple times** and will:
- ✅ Create a fresh backup
- ✅ Protect any new websites
- ✅ Leave already-protected sites untouched

### Common Issues

| Issue | Solution |
|-------|----------|
| **Permission denied** | Run with `sudo` |
| **Network timeout** | Try alternative methods above |
| **Process substitution fails** | Use Method 1 (download and run separately) |
| **FastPanel not found** | Ensure FastPanel is installed |
| **Nginx test fails** | Check syntax errors in existing configs |

## Repository Structure

```
WordPress-Security-with-Nginx-on-FastPanel/
├── README.md                          # This file
├── setup.sh                           # 🚀 1-command setup script
├── install-direct.sh                  # 🛠️ Direct installation script (recommended)
├── setup-alternative.sh               # 🔧 Alternative setup methods
├── nginx-includes/
│   └── wordpress-security.conf        # Main security configuration
└── scripts/
    ├── install.sh                     # Automated installation script
    ├── update-vhosts-nightly.sh       # Nightly FastPanel vhost refresher
    ├── uninstall.sh                   # Automated uninstallation script
    ├── test-security.sh               # Comprehensive security testing
    └── quick-test.sh                  # Quick security checks
```

## 🔧 Repository Topics

**Recommended GitHub Topics for this repository:**
```
wordpress-security, nginx, fastpanel, web-security, wordpress, security-hardening,
server-security, php-security, web-server, nginx-configuration, wordpress-protection,
cybersecurity, security-tools, web-hardening, server-hardening, penetration-testing,
security-audit, wordpress-hardening, nginx-security, hosting-security
```

> 💡 **Repository Owners:** Add these topics in your GitHub repository settings under Settings → Topics to improve discoverability!

## 📈 Contributing

Contributions are welcome! Please feel free to submit issues and enhancement requests:

- 🐛 **Bug Reports** - Found an issue? Please open an issue with details
- 💡 **Feature Requests** - Have an idea? We'd love to hear it
- 📚 **Documentation** - Help improve the guides and explanations
- 🔒 **Security** - Found a vulnerability? Please report responsibly

## 📄 License

MIT License - feel free to use and modify for your needs.

---

<div align="center">

**⭐ If this project helps secure your WordPress sites, please give it a star!**

Made with ❤️ for the WordPress community

[🔝 Back to top](#-wordpress-security-with-nginx-on-fastpanel)

</div>
