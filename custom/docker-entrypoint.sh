#!/bin/bash
set -e

echo 'Migrating database...'
php artisan october:migrate

echo 'Setting permissions...'
chown -R www-data:www-data /var/www/html/storage
chmod -R 755 /var/www/html/storage

chown -R www-data:www-data /var/www/html/app
chmod -R 755 /var/www/html/app

exec "$@"
