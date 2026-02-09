FROM php:8.3-fpm-bookworm

# Build argument for environment (development or production)
ARG ENVIRONMENT=development

# Install system dependencies
RUN apt-get update && apt-get install -y \
    apache2 \
    supervisor \
    cron \
    git \
    unzip \
    curl \
    nano \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

# Install certbot for production only (Let's Encrypt SSL)
RUN if [ "$ENVIRONMENT" = "production" ]; then \
    apt-get update && apt-get install -y certbot python3-certbot-apache \
    && rm -rf /var/lib/apt/lists/*; \
fi

# Switch Apache to event MPM for HTTP/2 support
# Note: ssl module enabled but SSL site only activated if certs exist (see entrypoint)
RUN a2dismod mpm_prefork \
    && a2enmod mpm_event rewrite headers proxy_fcgi setenvif http2 ssl

# Install PHP extensions required by October CMS
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        opcache \
        gd \
        zip \
        intl \
        xml \
        mbstring \
        bcmath \
    && pecl install redis xdebug \
    && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create PHP-FPM socket directory
RUN mkdir -p /run/php && chown www-data:www-data /run/php

# Copy configuration files
COPY apache.conf /etc/apache2/sites-available/000-default.conf
COPY apache-ssl.conf /etc/apache2/sites-available/default-ssl.conf
COPY php.ini /usr/local/etc/php/conf.d/october.ini
COPY php-fpm.conf /usr/local/etc/php-fpm.d/www.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Enable Apache site
RUN a2ensite 000-default

# Set working directory
WORKDIR /var/www/html

# Expose ports
EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
