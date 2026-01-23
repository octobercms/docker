# October CMS Base Docker Image
# Based on PHP 8.3 FPM with Apache (event MPM) for HTTP/2 support
#
# Build: docker build -t octobercms/base:1.0 .

FROM php:8.3-fpm-bookworm

LABEL maintainer="October CMS Docker"
LABEL description="Base image for October CMS deployments with HTTP/2 support"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_HOME=/var/www/.composer \
    OCTOBER_ROOT=/var/www/october \
    APACHE_DOCUMENT_ROOT=/var/www/october/public \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data

# Install system dependencies and Apache
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Apache with HTTP/2 support
    apache2 \
    libapache2-mod-fcgid \
    # Build tools
    build-essential \
    # Privilege management (needed for running commands as october user)
    sudo \
    # Version control
    git \
    # Archive tools
    unzip \
    zip \
    # Network tools
    curl \
    wget \
    # Process management
    supervisor \
    # Cron for scheduler
    cron \
    # Database clients
    default-mysql-client \
    redis-tools \
    # Image processing dependencies
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libwebp-dev \
    libavif-dev \
    # Compression
    libzip-dev \
    # Internationalization
    libicu-dev \
    # XML processing
    libxml2-dev \
    # String handling
    libonig-dev \
    # SSL
    libssl-dev \
    # YAML parsing (for launcher config)
    libyaml-dev \
    # Editor for convenience
    nano \
    vim \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Configure and install PHP extensions
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
        --with-avif \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        intl \
        opcache \
        pcntl \
        bcmath \
        exif \
        soap \
    && pecl install redis yaml \
    && docker-php-ext-enable redis yaml

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Create october user with same UID as www-data for permission consistency
RUN useradd --uid 1000 --gid www-data -m --shell /bin/bash october \
    && mkdir -p /var/www/october /shared /var/log/october \
    && chown -R october:www-data /var/www /shared /var/log/october

# Install October CMS via Composer
ARG OCTOBER_VERSION=""
RUN if [ -n "$OCTOBER_VERSION" ]; then \
        sudo -u october composer create-project october/october /var/www/october "$OCTOBER_VERSION" --no-interaction; \
    else \
        sudo -u october composer create-project october/october /var/www/october --no-interaction; \
    fi

# Backup default themes and plugins (for populating empty volume mounts at boot)
RUN mkdir -p /var/october-defaults \
    && cp -a /var/www/october/themes /var/october-defaults/themes \
    && cp -a /var/www/october/plugins /var/october-defaults/plugins

# Switch Apache from prefork to event MPM (required for HTTP/2)
RUN a2dismod mpm_prefork \
    && a2enmod mpm_event

# Configure Apache modules including HTTP/2
RUN a2enmod rewrite headers expires ssl proxy proxy_fcgi setenvif http2 \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Configure PHP-FPM to work with Apache
RUN a2enconf php8.3-fpm || true

# Create PHP-FPM pool configuration
RUN cat > /usr/local/etc/php-fpm.d/www.conf <<'EOF'
[www]
user = www-data
group = www-data
listen = /run/php/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
catch_workers_output = yes
php_admin_flag[log_errors] = on
php_admin_value[error_log] = /var/log/october/php-fpm-error.log
EOF

# Create PHP-FPM socket directory
RUN mkdir -p /run/php && chown www-data:www-data /run/php

# Create public directory (october:mirror will be run later during provisioning)
RUN mkdir -p /var/www/october/public \
    && chown october:www-data /var/www/october/public

# Create Apache virtual host configuration with HTTP/2
RUN cat > /etc/apache2/sites-available/october.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/october/public

    # Enable HTTP/2
    Protocols h2c http/1.1

    # Proxy PHP requests to PHP-FPM
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php-fpm.sock|fcgi://localhost"
    </FilesMatch>

    <Directory /var/www/october/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted

        # Handle Authorization Header
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.*)
        RewriteRule .* - [e=HTTP_AUTHORIZATION:%1]
    </Directory>

    # Deny access to sensitive files
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    # Logging
    ErrorLog /var/log/apache2/october-error.log
    CustomLog /var/log/apache2/october-access.log combined

    # Security headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"

    # Caching for static assets
    <FilesMatch "\.(ico|pdf|flv|jpg|jpeg|png|gif|webp|avif|js|css|swf|svg|woff|woff2|ttf|eot)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
</VirtualHost>
EOF

RUN a2ensite october && a2dissite 000-default

# PHP configuration for production
RUN cat > /usr/local/etc/php/conf.d/october.ini <<'EOF'
; October CMS PHP Configuration
memory_limit = 256M
upload_max_filesize = 50M
post_max_size = 50M
max_execution_time = 300
max_input_time = 300
max_input_vars = 5000

; Security
expose_php = Off
display_errors = Off
log_errors = On
error_log = /var/log/october/php-error.log

; Performance
realpath_cache_size = 4096K
realpath_cache_ttl = 600

; Session
session.cookie_httponly = 1
session.use_strict_mode = 1
EOF

# OPcache configuration
RUN cat > /usr/local/etc/php/conf.d/opcache.ini <<'EOF'
opcache.enable = 1
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.save_comments = 1
opcache.fast_shutdown = 1
opcache.jit = tracing
opcache.jit_buffer_size = 128M
EOF

# Supervisor base configuration
RUN mkdir -p /etc/supervisor/conf.d

COPY etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# PHP-FPM supervisor config
RUN cat > /etc/supervisor/conf.d/php-fpm.conf <<'EOF'
[program:php-fpm]
command=/usr/local/sbin/php-fpm --nodaemonize
autostart=true
autorestart=true
priority=5
startretries=5
startsecs=5
stdout_logfile=/var/log/supervisor/php-fpm-stdout.log
stderr_logfile=/var/log/supervisor/php-fpm-stderr.log
EOF

# Apache supervisor config
RUN cat > /etc/supervisor/conf.d/apache.conf <<'EOF'
[program:apache]
command=/usr/sbin/apache2ctl -D FOREGROUND
autostart=true
autorestart=true
priority=10
startretries=5
startsecs=5
stdout_logfile=/var/log/supervisor/apache-stdout.log
stderr_logfile=/var/log/supervisor/apache-stderr.log
EOF

# Boot script
COPY sbin/boot /sbin/boot
RUN chmod +x /sbin/boot

# Utility scripts
RUN cat > /usr/local/bin/october <<'EOF'
#!/bin/bash
cd /var/www/october && sudo -u october php artisan "$@"
EOF
RUN chmod +x /usr/local/bin/october

RUN cat > /usr/local/bin/october-composer <<'EOF'
#!/bin/bash
cd /var/www/october && sudo -u october /usr/bin/composer "$@"
EOF
RUN chmod +x /usr/local/bin/october-composer

# Create shared directories structure
RUN mkdir -p /shared/log /shared/uploads /shared/storage /shared/mysql /shared/redis

# Set working directory
WORKDIR /var/www/october

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Default command
CMD ["/sbin/boot"]