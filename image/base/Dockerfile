# October CMS Base Docker Image
# Based on PHP 8.3 with Apache and all required extensions
#
# Build: docker build -t octobercms/base:1.0 .

FROM php:8.3-apache-bookworm

LABEL maintainer="October CMS Docker"
LABEL description="Base image for October CMS deployments"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_HOME=/var/www/.composer \
    OCTOBER_ROOT=/var/www/october \
    APACHE_DOCUMENT_ROOT=/var/www/october/public \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# Configure Apache
RUN a2enmod rewrite headers expires ssl proxy proxy_fcgi setenvif \
    && sed -i 's|/var/www/html|/var/www/october/public|g' /etc/apache2/sites-available/000-default.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Create public directory (october:mirror will be run later during provisioning)
RUN mkdir -p /var/www/october/public \
    && chown october:www-data /var/www/october/public

# Create Apache virtual host configuration
RUN cat > /etc/apache2/sites-available/october.conf <<'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/october/public

    <Directory /var/www/october/public>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Logging
    ErrorLog /var/log/apache2/october-error.log
    CustomLog /var/log/apache2/october-access.log combined

    # Security headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
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
EOF

# Supervisor base configuration
RUN mkdir -p /etc/supervisor/conf.d

COPY etc/supervisor/supervisord.conf /etc/supervisor/supervisord.conf

# Apache supervisor config
RUN cat > /etc/supervisor/conf.d/apache.conf <<'EOF'
[program:apache]
command=/usr/sbin/apache2ctl -D FOREGROUND
autostart=true
autorestart=true
priority=100
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
