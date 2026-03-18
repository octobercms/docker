# Dockerfile for octobercms/october all-in-one image
#
# This is SEPARATE from docker/web/Dockerfile (the CLI tool's web container).
#
# CLI tool:  PHP 8.4 FPM + Apache (Supervisor), no DB, volume-mounted app
# This image: PHP 8.4 Apache (mod_php), embedded MariaDB 10.11, pre-installed October CMS
#
# Build:  docker build -t octobercms/october:latest .
# Run:    docker run -d -p 8080:80 octobercms/october:latest

# =============================================================================
# Stage 1: Build October CMS application
# =============================================================================
FROM composer:latest AS builder

# Create project
RUN composer create-project october/october /app "^4.0" --no-interaction --prefer-dist

# Copy our .env and generate a fresh app key
COPY misc/.env /app/.env
RUN cd /app && php artisan key:generate

# =============================================================================
# Stage 2: Runtime image
# =============================================================================
FROM php:8.4-apache-bookworm

# Pin MariaDB 10.11 via official repo (prevents version drift breakage)
RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://mariadb.org/mariadb_release_signing_key.pgp \
      | gpg --dearmor -o /etc/apt/keyrings/mariadb.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/mariadb.gpg] https://dlm.mariadb.com/repo/mariadb-server/10.11/repo/debian bookworm main" \
      > /etc/apt/sources.list.d/mariadb.list

# System + PHP deps + MariaDB 10.11
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libyaml-dev \
    libwebp-dev \
    libzip4 \
    libzip-dev \
    zlib1g-dev \
    libicu-dev \
    libpq-dev \
    libsqlite3-dev \
    g++ \
    git \
    cron \
    vim \
    nano \
    ssh-client \
    mariadb-server \
    mariadb-client \
 && docker-php-ext-install opcache \
 && docker-php-ext-configure intl \
 && docker-php-ext-install intl \
 && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
 && docker-php-ext-install -j"$(nproc)" gd \
 && docker-php-ext-install zip \
 && docker-php-ext-install exif \
 && docker-php-ext-install mysqli \
 && docker-php-ext-install pdo_pgsql \
 && docker-php-ext-install pdo_mysql \
 && rm -rf /var/lib/apt/lists/*

# MariaDB runtime dirs
RUN mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
RUN mkdir -p /var/lib/october-mysql && chown -R mysql:mysql /var/lib/october-mysql

# Bootstrap MariaDB: create database, set root password, enable remote access
COPY misc/db-bootstrap.sh /tmp/db-bootstrap.sh
RUN chmod +x /tmp/db-bootstrap.sh && /tmp/db-bootstrap.sh && rm /tmp/db-bootstrap.sh

# PHP config
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
  } > /usr/local/etc/php/conf.d/oc-opcache.ini

RUN { \
    echo 'log_errors=on'; \
    echo 'display_errors=off'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'max_execution_time=0'; \
    echo 'memory_limit=128M'; \
  } > /usr/local/etc/php/conf.d/oc-php.ini

# Apache
RUN a2enmod rewrite

# Copy pre-built October CMS from builder stage
COPY --from=builder /app /var/octobercms-source

# Verify the build
RUN test -f /var/octobercms-source/artisan || { echo 'Build failed: artisan not found'; exit 1; }
RUN test -d /var/octobercms-source/modules || { echo 'Build failed: modules dir not found'; exit 1; }

# Entrypoint script (runtime)
COPY misc/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Composer (for runtime operations like theme:seed)
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Cron (as www-data)
USER www-data
RUN (crontab -l 2>/dev/null; echo "* * * * * cd /var/www/html;/usr/local/bin/php artisan schedule:run 1>> /dev/null 2>&1") | crontab -
USER root

# Volumes for persistence
VOLUME ["/var/lib/october-mysql"]
VOLUME ["/var/www/html"]

# Ports
EXPOSE 3306/tcp
EXPOSE 80/tcp

# Entrypoint
CMD ["/usr/local/bin/entrypoint.sh"]
