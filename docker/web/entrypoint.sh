#!/bin/bash
set -e

# Allow git operations in the mounted volume (owned by different UIDs)
git config --global --add safe.directory /var/www/html

# Enable or disable Xdebug based on environment
if [ "$APP_ENV" = "production" ] || [ "$XDEBUG_MODE" = "off" ]; then
    # Disable Xdebug in production
    if [ -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini ]; then
        rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini
    fi
else
    # Enable Xdebug in development
    docker-php-ext-enable xdebug 2>/dev/null || true
fi

# SSL Configuration for production
if [ "$APP_ENV" = "production" ]; then
    if [ "$SSL_MODE" = "letsencrypt" ]; then
        # Let's Encrypt automatic certificates
        CERT_PATH="/etc/letsencrypt/live/$APP_HOSTNAME"

        if [ ! -f "$CERT_PATH/fullchain.pem" ]; then
            echo "============================================"
            echo "Obtaining Let's Encrypt certificate..."
            echo "============================================"

            # Use standalone mode (Apache not running yet - supervisor starts it later)
            certbot certonly --standalone \
                --non-interactive \
                --agree-tos \
                --email "$LETSENCRYPT_EMAIL" \
                --domains "$APP_HOSTNAME"

            # Create symlinks to standard paths
            if [ -f "$CERT_PATH/fullchain.pem" ]; then
                ln -sf "$CERT_PATH/fullchain.pem" /etc/ssl/certs/october.crt
                ln -sf "$CERT_PATH/privkey.pem" /etc/ssl/private/october.key
                echo "SSL certificate obtained successfully!"
            else
                echo "ERROR: Failed to obtain SSL certificate"
                echo "       Make sure your domain points to this server and ports 80/443 are open"
            fi
        else
            # Certs already exist, ensure symlinks are in place
            ln -sf "$CERT_PATH/fullchain.pem" /etc/ssl/certs/october.crt
            ln -sf "$CERT_PATH/privkey.pem" /etc/ssl/private/october.key
        fi

        # Set up auto-renewal cron job (cron managed by supervisor)
        echo "0 0 * * * root certbot renew --quiet --post-hook 'apachectl graceful'" > /etc/cron.d/certbot-renew
        chmod 644 /etc/cron.d/certbot-renew

        # Enable SSL site if certs exist
        if [ -f /etc/ssl/certs/october.crt ]; then
            echo "Enabling SSL..."
            a2ensite default-ssl 2>/dev/null || true
        fi

    elif [ "$SSL_MODE" = "custom" ]; then
        # Custom certificates (user-provided)
        if [ -f /etc/ssl/certs/october.crt ] && [ -f /etc/ssl/private/october.key ]; then
            echo "Enabling SSL with custom certificates..."
            a2ensite default-ssl 2>/dev/null || true
        else
            echo "WARNING: Custom SSL mode but certificates not found"
            echo "         Mount certificates to /etc/ssl/certs/october.crt and /etc/ssl/private/october.key"
        fi
    fi
    # SSL_MODE=none means HTTP only, do nothing
fi

# First-run: Install October if directory is empty
if [ ! -f /var/www/html/artisan ]; then
    echo "============================================"
    echo "October CMS not found. Installing..."
    echo "============================================"

    install_failed=0

    (
        set -e
        cd /var/www/html

        if [ -n "$OCTOBER_REPO" ]; then
            echo "Cloning from custom repo: $OCTOBER_REPO"

            # Preserve our .env file (has APP_KEY, DB credentials, etc.)
            cp /var/www/html/.env /tmp/env-backup 2>/dev/null || true

            # Clone to temp directory (site dir may already contain .env)
            if [ -n "$OCTOBER_BRANCH" ]; then
                echo "Using branch: $OCTOBER_BRANCH"
                git clone -b "$OCTOBER_BRANCH" "$OCTOBER_REPO" /tmp/october-install
            else
                git clone "$OCTOBER_REPO" /tmp/october-install
            fi

            # Remove repo's .env if present (we have our own)
            rm -f /tmp/october-install/.env 2>/dev/null || true

            # Move all files including hidden ones (except . and ..)
            shopt -s dotglob
            mv /tmp/october-install/* /var/www/html/ 2>/dev/null || true
            shopt -u dotglob
            rm -rf /tmp/october-install

            # Restore our .env file
            cp /tmp/env-backup /var/www/html/.env 2>/dev/null || true
            rm -f /tmp/env-backup

            # Install dependencies (dev or prod based on environment)
            if [ "$APP_ENV" = "production" ]; then
                echo "Installing dependencies (production)..."
                composer install --no-interaction --no-dev --optimize-autoloader
            else
                echo "Installing dependencies (development)..."
                composer install --no-interaction
            fi
        else
            echo "Installing fresh October CMS via Composer..."

            # Preserve our .env file (has APP_KEY, DB credentials, etc.)
            cp /var/www/html/.env /tmp/env-backup 2>/dev/null || true

            # Install to temp directory (site dir may already contain .env)
            composer create-project october/october /tmp/october-install --no-interaction

            # Remove October's generated .env (we have our own)
            rm -f /tmp/october-install/.env 2>/dev/null || true

            # Move all files including hidden ones (except . and ..)
            shopt -s dotglob
            mv /tmp/october-install/* /var/www/html/ 2>/dev/null || true
            shopt -u dotglob
            rm -rf /tmp/october-install

            # Restore our .env file
            cp /tmp/env-backup /var/www/html/.env 2>/dev/null || true
            rm -f /tmp/env-backup
        fi
    ) || install_failed=1

    if [ "$install_failed" = "1" ]; then
        echo "============================================"
        echo "WARNING: Installation failed!"
        echo "         Container will start anyway."
        echo "         Use './launcher enter <site>' to debug."
        echo "============================================"
    else
        # Set permissions for the application tree mounted from the host
        echo "Setting permissions..."
        find /var/www/html -exec chown www-data:www-data {} +
        chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

        # Clear any cached configuration (ensures .env values are used)
        echo "Clearing config cache..."
        php artisan config:clear 2>/dev/null || true
        php artisan cache:clear 2>/dev/null || true

        # Verify .env has required database configuration
        if [ -f /var/www/html/.env ]; then
            if grep -q "^DB_DATABASE=" /var/www/html/.env && grep -q "^DB_USERNAME=" /var/www/html/.env; then
                echo "Environment file verified."
            else
                echo "WARNING: .env file missing database configuration!"
                echo "         DB_DATABASE and DB_USERNAME are required."
            fi
        else
            # Copy from .env.example if our .env is missing
            if [ -f /var/www/html/.env.example ]; then
                echo "WARNING: .env file not found, copying from .env.example"
                echo "         You may need to update database credentials!"
                cp /var/www/html/.env.example /var/www/html/.env
            fi
        fi

        echo "============================================"
        echo "October CMS installed successfully!"
        echo "============================================"
    fi
fi

# Wait for database and run migrations on every start
cd /var/www/html
echo "Waiting for database..."
max_tries=30
tries=0
while ! php -r "new PDO('mysql:host='.getenv('DB_HOST').';port='.getenv('DB_PORT'), getenv('DB_USERNAME'), getenv('DB_PASSWORD'));" 2>/dev/null; do
    tries=$((tries + 1))
    if [ $tries -ge $max_tries ]; then
        echo "WARNING: Database not available after $max_tries attempts"
        break
    fi
    echo "  Database not ready, waiting... ($tries/$max_tries)"
    sleep 2
done

if [ $tries -lt $max_tries ]; then
    echo "Running migrations..."
    if ! php artisan october:migrate 2>&1; then
        if ! php artisan october:up 2>&1; then
            echo "Migrations skipped. Run 'php artisan october:install' manually."
        fi
    fi

    # Create/update public directory mirror
    echo "Updating public directory..."
    mkdir -p /var/www/html/public
    chown www-data:www-data /var/www/html/public
    php artisan october:mirror --relative 2>/dev/null || true
fi

# Ensure permissions are correct on every start
chown -R www-data:www-data /var/www/html/storage 2>/dev/null || true
chown -R www-data:www-data /var/www/html/bootstrap/cache 2>/dev/null || true

# Dump container environment for cron (cron runs with a minimal environment)
env >> /etc/environment

# Set up cron job to keep public directory mirror in sync (cron managed by supervisor)
printf "* * * * * www-data cd /var/www/html && /usr/local/bin/php artisan october:mirror --relative --quiet 2>/dev/null\n" > /etc/cron.d/october-mirror
chmod 644 /etc/cron.d/october-mirror

# Development mode: Make files accessible to host user for editing
# This allows VS Code and other editors on the host to modify files
if [ "$APP_ENV" != "production" ]; then
    echo "Development mode: Setting group-writable permissions..."
    chmod -R 775 /var/www/html 2>/dev/null || true
fi

exec "$@"
