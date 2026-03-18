#!/usr/bin/env bash
set -euo pipefail

# Start MariaDB without auth (unix_socket plugin blocks root in Docker builds)
mariadbd-safe --skip-grant-tables --skip-networking &>/dev/null &

# Wait for it to be ready
for i in $(seq 1 30); do
    if mariadb -u root -e "SELECT 1" &>/dev/null; then
        echo "MariaDB is ready."
        break
    fi
    sleep 1
done

# Configure auth and create database
mariadb -u root <<'SQL'
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS octobercms;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

echo "MariaDB bootstrap complete."
mariadb-admin -u root -proot shutdown
