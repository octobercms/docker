#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Version banner
# -----------------------------------------------------------------------------
echo "=== October CMS Docker ==="
echo "Debian:  $(cat /etc/debian_version 2>/dev/null || echo 'unknown')"
echo "PHP:     $(php -r 'echo PHP_VERSION;')"
echo "Apache:  $(apache2 -v 2>/dev/null | awk -F/ '/Server version/ {print $2}' | awk '{print $1}')"
echo "MariaDB: $(mariadbd --version 2>/dev/null | awk '{print $3}' || echo 'unknown')"
echo "=========================="

# -----------------------------------------------------------------------------
# 1) Copy application code on first run
# -----------------------------------------------------------------------------
if [ ! -f /var/www/html/artisan ]; then
    echo "First run: copying October CMS files..."
    cp -r /var/octobercms-source/. /var/www/html/
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html

fi

# -----------------------------------------------------------------------------
# 2) MariaDB config and data dir
# -----------------------------------------------------------------------------
DATADIR="/var/lib/october-mysql"

if [ ! -f /root/mysql-configured ]; then
    echo "Configuring MariaDB..."
    cat > /etc/mysql/mariadb.conf.d/51-server-remote.cnf <<EOF
[mysqld]
skip-networking=0
skip-bind-address
bind-address=0.0.0.0
datadir=$DATADIR
EOF

    mkdir -p "$DATADIR"
    if [ -z "$(ls -A "$DATADIR" 2>/dev/null)" ]; then
        echo "Initializing datadir at $DATADIR..."
        cp -RT /var/lib/mysql "$DATADIR"
    fi

    chown -R mysql:mysql "$DATADIR"
    touch /root/mysql-configured
fi

# -----------------------------------------------------------------------------
# 3) Start MariaDB and wait until ready
# -----------------------------------------------------------------------------
echo "Starting MariaDB..."
service mariadb start

for i in $(seq 1 60); do
    if mysqladmin ping -u root -proot --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

if ! mysqladmin ping -u root -proot --silent 2>/dev/null; then
    echo "MariaDB failed to start." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 4) Run migrations on every start (picks up updates when image changes)
#    Also creates the database on first run via october:migrate
# -----------------------------------------------------------------------------
echo "Running migrations..."
cd /var/www/html
if ! php artisan october:migrate 2>&1; then
    if ! php artisan october:up 2>&1; then
        echo "WARNING: Migrations failed. Run 'php artisan october:migrate' manually."
    fi
fi

# Fix permissions
chown -R www-data:www-data /var/www/html/storage 2>/dev/null || true
chown -R www-data:www-data /var/www/html/bootstrap/cache 2>/dev/null || true

# -----------------------------------------------------------------------------
# 5) Start cron + apache
# -----------------------------------------------------------------------------
service cron start
service apache2 start

# -----------------------------------------------------------------------------
# 6) Graceful shutdown
# -----------------------------------------------------------------------------
stop_services() {
    echo "Stopping services..."
    service apache2 stop || true
    service mariadb stop || true
    exit 0
}
trap stop_services SIGTERM SIGINT

# Keep container alive, stream logs
tail -F /var/log/apache2/access.log /var/log/apache2/error.log 2>/dev/null &
wait $!
