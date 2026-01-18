# October CMS Development Docker Image
# Includes Xdebug, development tools, and dev-friendly PHP settings
#
# Build: docker build -t octobercms/dev:1.0 .
# Build with custom base: docker build --build-arg BASE_IMAGE=octobercms/base:2.0 -t octobercms/dev:2.0 .

ARG BASE_IMAGE=octobercms/base:1.0
FROM ${BASE_IMAGE}

LABEL maintainer="October CMS Docker"
LABEL description="Development image for October CMS with Xdebug"

# Install development dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Development tools
    vim \
    less \
    htop \
    # Node.js for frontend development
    nodejs \
    npm \
    # SQLite for testing
    sqlite3 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Xdebug
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

# Install SQLite extension for testing
RUN docker-php-ext-install pdo_sqlite

# PHP development configuration
RUN cat > /usr/local/etc/php/conf.d/99-dev.ini <<'EOF'
; Development PHP Configuration

; Error reporting
display_errors = On
display_startup_errors = On
error_reporting = E_ALL
log_errors = On
error_log = /var/log/october/php-error.log

; Memory and limits (more generous for development)
memory_limit = 512M
max_execution_time = 0
max_input_time = -1

; OPcache - validate timestamps for development
opcache.validate_timestamps = 1
opcache.revalidate_freq = 0

; Disable JIT in development (can cause issues with Xdebug)
opcache.jit = off
EOF

# Xdebug configuration
RUN cat > /usr/local/etc/php/conf.d/99-xdebug.ini <<'EOF'
; Xdebug Configuration for Development
xdebug.mode = debug,develop,coverage
xdebug.start_with_request = yes
xdebug.discover_client_host = true
xdebug.client_host = host.docker.internal
xdebug.client_port = 9003
xdebug.log = /var/log/october/xdebug.log
xdebug.log_level = 1

; IDE key for PhpStorm/VS Code
xdebug.idekey = PHPSTORM

; Show better error pages
xdebug.show_error_trace = 1
xdebug.show_local_vars = 1
EOF

# Create Xdebug log file
RUN touch /var/log/october/xdebug.log \
    && chown october:www-data /var/log/october/xdebug.log

# Development environment variables
ENV APP_ENV=local \
    APP_DEBUG=true \
    XDEBUG_MODE=debug,develop,coverage \
    XDEBUG_CONFIG="client_host=host.docker.internal"

# Development helper scripts
RUN cat > /usr/local/bin/october-test <<'EOF'
#!/bin/bash
cd /var/www/october
sudo -u october php artisan test "$@"
EOF
RUN chmod +x /usr/local/bin/october-test

RUN cat > /usr/local/bin/october-tinker <<'EOF'
#!/bin/bash
cd /var/www/october
sudo -u october php artisan tinker "$@"
EOF
RUN chmod +x /usr/local/bin/october-tinker

RUN cat > /usr/local/bin/xdebug-on <<'EOF'
#!/bin/bash
echo "Enabling Xdebug..."
phpenmod xdebug
apache2ctl graceful
echo "Xdebug enabled"
EOF
RUN chmod +x /usr/local/bin/xdebug-on

RUN cat > /usr/local/bin/xdebug-off <<'EOF'
#!/bin/bash
echo "Disabling Xdebug..."
phpdismod xdebug
apache2ctl graceful
echo "Xdebug disabled"
EOF
RUN chmod +x /usr/local/bin/xdebug-off

# Expose Xdebug port
EXPOSE 9003
