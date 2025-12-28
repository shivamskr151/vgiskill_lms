#!/bin/bash
set -e

# Function to check if database tables exist
check_db_tables() {
    python3 << PYTHON
import MySQLdb
import sys
import os
try:
    conn = MySQLdb.connect(
        host=os.environ.get('DB_HOST', '10.30.0.2'),
        port=int(os.environ.get('DB_PORT', '3306')),
        user=os.environ.get('DB_USER', 'vgi_skill'),
        passwd=os.environ.get('DB_PASSWORD', 'vgiskill@2026'),
        db=os.environ.get('DB_NAME', 'lms_db')
    )
    cursor = conn.cursor()
    cursor.execute("SHOW TABLES LIKE 'tabDefaultValue'")
    result = cursor.fetchone()
    conn.close()
    sys.exit(0 if result else 1)
except Exception as e:
    print(f"Error checking tables: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
}

# Wait for database to be ready
echo "Waiting for database to be ready..."
until nc -z ${DB_HOST:-10.30.0.2} ${DB_PORT:-3306}; do
    echo "Database is unavailable - sleeping"
    sleep 2
done
echo "Database is ready!"

# Set working directory
cd /home/frappe/frappe-bench

# Ensure apps.txt exists (required by bench commands)
if [ ! -f sites/apps.txt ]; then
    echo "Creating apps.txt..."
    echo "frappe" > sites/apps.txt
    echo "lms" >> sites/apps.txt
fi

# Configure database connection
SITE_DIR="sites/${SITE_NAME:-vgiskill.ai}"

# Set database configuration (if bench set-mariadb-host exists, use it)
bench set-mariadb-host ${DB_HOST:-10.30.0.2} 2>/dev/null || bench set-config -g db_host ${DB_HOST:-10.30.0.2} || true

# Check if site exists and has valid database tables
SITE_EXISTS=false
if [ -d "$SITE_DIR" ]; then
    echo "Site directory exists, checking if database tables were created..."
    if check_db_tables 2>/dev/null; then
        echo "✅ Database tables exist, site is valid"
        SITE_EXISTS=true
    else
        echo "⚠️  WARNING: Site directory exists but database tables are missing!"
        echo "Removing incomplete site directory to recreate..."
        rm -rf "$SITE_DIR"
        SITE_EXISTS=false
    fi
fi

# Create site if it doesn't exist or was invalid
if [ "$SITE_EXISTS" = false ]; then
    echo "Creating new site: ${SITE_NAME:-vgiskill.ai}"
    echo "This may take a few minutes..."
    
    # Build bench new-site command with root password flag
    if [ -n "${DB_ROOT_PASSWORD:-}" ]; then
        echo "Using provided root password for database setup..."
        bench new-site ${SITE_NAME:-vgiskill.ai} \
            --db-host ${DB_HOST:-10.30.0.2} \
            --db-port ${DB_PORT:-3306} \
            --db-name ${DB_NAME:-lms_db} \
            --db-user ${DB_USER:-vgi_skill} \
            --db-password ${DB_PASSWORD} \
            --mariadb-root-password ${DB_ROOT_PASSWORD} \
            --admin-password ${ADMIN_PASSWORD:-admin} \
            --no-mariadb-socket \
            --force 2>&1 | tee /tmp/site-creation.log
        BENCH_EXIT=${PIPESTATUS[0]}
    else
        echo "No root password provided - bench will try to use existing DB user permissions..."
        echo "If this fails, ensure DB user has CREATE, DROP, ALTER, INDEX permissions"
        bench new-site ${SITE_NAME:-vgiskill.ai} \
            --db-host ${DB_HOST:-10.30.0.2} \
            --db-port ${DB_PORT:-3306} \
            --db-name ${DB_NAME:-lms_db} \
            --db-user ${DB_USER:-vgi_skill} \
            --db-password ${DB_PASSWORD} \
            --admin-password ${ADMIN_PASSWORD:-admin} \
            --no-mariadb-socket \
            --force 2>&1 | tee /tmp/site-creation.log
        BENCH_EXIT=${PIPESTATUS[0]}
    fi
    
    if [ $BENCH_EXIT -eq 0 ]; then
        echo "✅ Site creation command completed successfully!"
        
        # Wait a moment for database operations to complete
        sleep 5
        
        # If bench new-site exited successfully, the site was created
        # The check might fail due to Python environment, but if bench succeeded, we're good
        if [ -d "$SITE_DIR" ]; then
            echo "✅ Site directory created successfully!"
            echo "Proceeding with LMS app installation..."
        else
            echo "❌ ERROR: Site directory was not created!"
            cat /tmp/site-creation.log || true
            exit 1
        fi
        
        # Disable Redis configuration completely to prevent connection errors
        # Redis requires authentication which we don't have, so use FileCache instead
        echo "Disabling Redis configuration completely (using FileCache)..."
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g redis_queue "" || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g redis_cache "" || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g redis_socketio "" || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g background_jobs 0 || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g use_redis_cache 0 || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g use_redis_queue 0 || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g use_redis_socketio 0 || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g enable_scheduler 0 || true
        bench --site ${SITE_NAME:-vgiskill.ai} set-config -g cache_type FileCache || true
        # Also update site_config.json directly to ensure Redis is disabled
        python3 << PYTHON
import json
import os
site_config_path = "/home/frappe/frappe-bench/sites/${SITE_NAME:-vgiskill.ai}/site_config.json"
if os.path.exists(site_config_path):
    with open(site_config_path, "r") as f:
        config = json.load(f)
    # Remove all Redis entries
    config.pop("redis_queue", None)
    config.pop("redis_cache", None)
    config.pop("redis_socketio", None)
    config["background_jobs"] = 0
    config["use_redis_cache"] = False
    config["use_redis_queue"] = False
    config["use_redis_socketio"] = False
    with open(site_config_path, "w") as f:
        json.dump(config, f, indent=1)
    print("✅ Redis completely disabled in site_config.json")
PYTHON
        echo "✅ Redis configuration completely disabled"
        
        # Install LMS app
        echo "Installing LMS app..."
        bench --site ${SITE_NAME:-vgiskill.ai} install-app lms 2>&1 | tee /tmp/install-app.log || {
            echo "⚠️  LMS app installation had issues:"
            cat /tmp/install-app.log || true
        }
        
        # Link assets from bench apps to site assets directory
        echo "Linking assets to site..."
        mkdir -p sites/${SITE_NAME:-vgiskill.ai}/assets
        ln -sf /home/frappe/frappe-bench/apps/frappe/frappe/public sites/${SITE_NAME:-vgiskill.ai}/assets/frappe || true
        ln -sf /home/frappe/frappe-bench/apps/lms/lms/public sites/${SITE_NAME:-vgiskill.ai}/assets/lms || true
        echo "✅ Assets linked"
        
        # Build assets for the site (this generates the correct bundle hashes)
        echo "Building assets for site..."
        bench --site ${SITE_NAME:-vgiskill.ai} build --app frappe --app lms --production 2>&1 || echo "⚠️ Asset build had warnings, continuing..."
    else
        echo "❌ ERROR: Site creation failed!"
        echo "Site creation log:"
        cat /tmp/site-creation.log || true
        exit 1
    fi
fi

# Use the site (only if it exists)
if [ -d "sites/${SITE_NAME:-vgiskill.ai}" ]; then
    bench use ${SITE_NAME:-vgiskill.ai}
    
    # Disable Redis configuration completely to prevent authentication errors
    # Redis requires authentication which causes 500 errors - always use FileCache
    echo "Ensuring Redis is completely disabled (using FileCache to avoid authentication errors)..."
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g redis_queue "" || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g redis_cache "" || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g redis_socketio "" || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g background_jobs 0 || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g use_redis_cache 0 || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g use_redis_queue 0 || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g use_redis_socketio 0 || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g enable_scheduler 0 || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g cache_type FileCache || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g rate_limit 0 || true
    bench --site ${SITE_NAME:-vgiskill.ai} set-config -g enable_rate_limit 0 || true
    # Always disable Redis and use FileCache to avoid authentication errors
    # Redis requires authentication which causes 500 errors when accessing desk routes
    python3 << PYTHON
import json
import os

site_config_path = "/home/frappe/frappe-bench/sites/${SITE_NAME:-vgiskill.ai}/site_config.json"

if os.path.exists(site_config_path):
    with open(site_config_path, "r") as f:
        config = json.load(f)
    
    # Always disable Redis - it requires authentication which causes errors
    print("⚠️ Disabling Redis completely (using FileCache to avoid authentication errors)")
    config.pop("redis_queue", None)
    config.pop("redis_cache", None)
    config.pop("redis_socketio", None)
    config["background_jobs"] = 0
    config["use_redis_cache"] = False
    config["use_redis_queue"] = False
    config["use_redis_socketio"] = False
    config["enable_scheduler"] = False
    config["cache_type"] = "FileCache"
    # Disable rate limiting to prevent Redis cache usage
    config["rate_limit"] = False
    config["enable_rate_limit"] = False
    
    # Remove any other Redis-related keys
    for key in list(config.keys()):
        if "redis" in key.lower() and key not in ["use_redis_cache", "use_redis_queue", "use_redis_socketio"]:
            del config[key]
    
    with open(site_config_path, "w") as f:
        json.dump(config, f, indent=1)
    print("✅ site_config.json updated - Redis disabled, FileCache enabled")
PYTHON
    echo "✅ Redis configuration updated - using FileCache"
    
    # Ensure assets are linked to the site
    echo "Ensuring assets are linked..."
    if [ ! -d "sites/${SITE_NAME:-vgiskill.ai}/assets/frappe" ]; then
        echo "Linking assets to site..."
        mkdir -p sites/${SITE_NAME:-vgiskill.ai}/assets
        ln -sf /home/frappe/frappe-bench/apps/frappe/frappe/public sites/${SITE_NAME:-vgiskill.ai}/assets/frappe || true
        ln -sf /home/frappe/frappe-bench/apps/lms/lms/public sites/${SITE_NAME:-vgiskill.ai}/assets/lms || true
        echo "✅ Assets linked"
        
        # Build assets to generate correct bundle hashes
        echo "Building assets for site..."
        bench --site ${SITE_NAME:-vgiskill.ai} build --app frappe --app lms --production 2>&1 || echo "⚠️ Asset build had warnings, continuing..."
    fi
    
    # Clear all caches to ensure fresh asset hashes
    echo "Clearing all caches..."
    bench --site ${SITE_NAME:-vgiskill.ai} clear-cache || true
    bench --site ${SITE_NAME:-vgiskill.ai} clear-website-cache || true
    rm -rf sites/${SITE_NAME:-vgiskill.ai}/.cache || true
    rm -rf sites/${SITE_NAME:-vgiskill.ai}/private/cache || true
    
    # Create symlinks for commonly requested asset hashes to actual files
    # This fixes the mismatch between HTML-requested hashes and actual file hashes
    echo "Creating asset symlinks for compatibility..."
    if [ -d "apps/frappe/frappe/public/dist/css" ]; then
        cd apps/frappe/frappe/public/dist/css
        ACTUAL_WEBSITE=$(ls website.bundle.*.css 2>/dev/null | head -1)
        ACTUAL_LOGIN=$(ls login.bundle.*.css 2>/dev/null | head -1)
        if [ -n "$ACTUAL_WEBSITE" ] && [ ! -f "website.bundle.6KFGFHJ7.css" ]; then
            ln -sf "$ACTUAL_WEBSITE" website.bundle.6KFGFHJ7.css 2>/dev/null || true
        fi
        if [ -n "$ACTUAL_LOGIN" ] && [ ! -f "login.bundle.OP4BR2AN.css" ]; then
            ln -sf "$ACTUAL_LOGIN" login.bundle.OP4BR2AN.css 2>/dev/null || true
        fi
        cd /home/frappe/frappe-bench
        echo "✅ Asset symlinks created"
    fi
fi

# Create a patch to disable rate limiting (prevents Redis connection errors)
echo "Creating rate limiter patch..."
mkdir -p sites/${SITE_NAME:-vgiskill.ai}/patches
cat > sites/${SITE_NAME:-vgiskill.ai}/patches/disable_rate_limit.py << 'PATCH'
# Patch to disable rate limiting and prevent Redis connection errors
import frappe

def patched_check_rate_limit(*args, **kwargs):
    # Always allow, don't check rate limit (avoids Redis connection)
    return True

# Apply patch after Frappe is initialized
def after_migrate():
    try:
        import frappe.rate_limiter as rate_limiter_module
        rate_limiter_module.check_rate_limit = patched_check_rate_limit
    except:
        pass
PATCH
echo "✅ Rate limiter patch created"

# Start bench web server only (no Redis required)
echo "Starting bench web server on port 8000..."
exec bench serve --port 8000
