# Multi Stage Build: Part 1
# -------------------------
FROM php:8.1-apache as intermediate

RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    libpng-dev \
    libzip4 \
    libzip-dev \
    git \
    && docker-php-ext-install zip \
    && docker-php-ext-install -j$(nproc) gd

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN composer create-project october/october . --no-interaction --prefer-dist

RUN sed -i 's/DB_CONNECTION=mysql/DB_CONNECTION=sqlite/' .env && \
    sed -i 's/DB_DATABASE=database/DB_DATABASE=storage\/database.sqlite/' .env

ARG LICENSE_KEY

# Artisan commands
RUN php artisan key:generate && \
    php artisan project:set ${LICENSE_KEY} && \
    php artisan october:build

# Delete license key
# RUN rm auth.json && \
#     rm storage/cms/project.json

# Multi Stage Build: Part 2
# -------------------------
FROM php:8.1-apache
LABEL maintainer="October CMS <hello@octobercms.com> (@octobercms)"

# Enables apache rewrite w/ security
RUN a2enmod rewrite expires && \
    sed -i 's/ServerTokens OS/ServerTokens ProductOnly/g' \
    /etc/apache2/conf-available/security.conf

# Installs dependencies
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
    && docker-php-ext-install opcache \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install zip \
    && docker-php-ext-install exif \
    && docker-php-ext-install mysqli \
    && docker-php-ext-install pdo_pgsql \
    && docker-php-ext-install pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

# Sets recommended PHP.ini settings (https://secure.php.net/manual/en/opcache.installation.php)
RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=2'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'upload_max_filesize=128M'; \
    echo 'post_max_size=128M'; \
    echo 'expose_php=off'; \
    } > /usr/local/etc/php/conf.d/php-recommended.ini

RUN pecl install apcu \
    && pecl install yaml-2.2.2 \
    && docker-php-ext-enable apcu yaml

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Copy install from previous image
COPY --chown=www-data:www-data --from=intermediate /var/www/html /var/www/html

# Sets user to www-data
USER www-data

# Adds SQLite database
WORKDIR /var/www/html
RUN touch storage/database.sqlite && \
    chmod 666 storage/database.sqlite

# Creates cron job for maintenance scripts
RUN (crontab -l; echo "* * * * * cd /var/www/html;/usr/local/bin/php artisan schedule:run 1>> /dev/null 2>&1") | crontab -

# Returns to root user
USER root

# Copies init scripts
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Provides container inside image for data persistence
VOLUME ["/var/www/html"]

ENTRYPOINT ["/entrypoint.sh"]
# CMD ["apache2-foreground"]
CMD ["sh", "-c", "cron && apache2-foreground"]
