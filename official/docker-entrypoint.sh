#!/bin/bash
set -e

echo 'Setting permissions...'
chown -R www-data:www-data /var/www/html/storage
chmod -R 755 /var/www/html/storage

exec "$@"
