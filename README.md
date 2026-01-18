# October CMS Docker

A Docker-based deployment system for [October CMS](https://octobercms.com/).

This project provides a streamlined way to deploy, manage, and maintain October CMS installations using Docker containers with flexible, composable configuration.

## Features

- **Minimal host dependencies** - Only requires Bash and Docker
- **Template composition** - Modular YAML templates for flexible configuration
- **Interactive setup wizard** - Guided first-time configuration
- **Health diagnostics** - Built-in doctor tool for troubleshooting
- **Multiple deployment modes** - Standalone, multi-container, dev, and production
- **Automatic SSL** - Let's Encrypt integration for free HTTPS
- **Resource auto-tuning** - Automatic optimization based on system resources

## Quick Start

### Prerequisites

- Docker 20.10 or later
- Bash (Linux, macOS, WSL, or Git Bash on Windows)
- 2GB+ RAM recommended
- 5GB+ disk space

> **Note**: Unlike typical PHP projects, you don't need PHP, Composer, or any other dependencies installed on the host. All PHP operations run inside Docker containers.

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/october-docker.git
   cd october-docker/october
   ```

2. Run the setup wizard:
   ```bash
   ./october-setup
   ```

3. Or manually configure and bootstrap:
   ```bash
   cp samples/standalone.yml containers/app.yml
   # Edit containers/app.yml with your settings
   ./launcher bootstrap app
   ```

4. Access your site at the configured URL!

### Windows Users

1. Install Docker Desktop
2. Install Ubuntu (via Microsoft Store)
3. Turn on [Docker Desktop WSL 2](https://docs.docker.com/desktop/features/wsl/#turn-on-docker-desktop-wsl-2) (Settings → General → Use WSL 2 Based Engine)
4. Turn on WSL integration with Ubuntu (Settings → Resources → WSL Integration)

On Windows, use Git Bash, WSL, or any Bash-compatible shell:
```bash
# Git Bash
./october-setup

# Or use the batch wrapper
october-setup.bat
```

## Commands

### Launcher Commands

| Command | Description |
|---------|-------------|
| `./launcher start app` | Start the container |
| `./launcher stop app` | Stop the container |
| `./launcher restart app` | Restart the container |
| `./launcher rebuild app` | Destroy and rebuild |
| `./launcher enter app` | Open a shell inside |
| `./launcher logs app` | View container logs |
| `./launcher logs app -f` | Follow logs in real-time |
| `./launcher artisan app migrate` | Run artisan commands |
| `./launcher bootstrap app` | Create new container |
| `./launcher destroy app` | Remove container |
| `./launcher cleanup` | Remove stopped containers |

### Other Tools

```bash
./october-setup      # Interactive configuration wizard
./october-doctor     # Health check and diagnostics
```

## Configuration

### Directory Structure

```
october/
├── launcher              # Main CLI tool (Bash)
├── october-setup         # Setup wizard (Bash)
├── october-doctor        # Diagnostics tool (Bash)
├── image/                # Docker images
│   ├── base/             # Base production image
│   ├── dev/              # Development image
│   └── prod/             # Optimized production image
├── templates/            # YAML templates
├── samples/              # Sample configurations
├── containers/           # Your container configs (gitignored)
├── shared/               # Persistent data (gitignored)
└── cids/                 # Container IDs (gitignored)
```

### Container Configuration

Container configurations are YAML files in the `containers/` directory:

```yaml
# containers/app.yml

templates:
  - "templates/mysql.template.yml"
  - "templates/redis.template.yml"
  - "templates/web.template.yml"

expose:
  - "80:80"
  - "443:443"

volumes:
  - volume:
      host: /var/october/shared/{{ config }}
      guest: /shared

params:
  repo_url: https://github.com/octobercms/october.git
  version: main
  php_memory_limit: 256M

env:
  APP_KEY: "base64:your-key-here"
  APP_URL: "https://example.com"
  DB_PASSWORD: "secure-password"

hooks:
  after_composer:
    - exec:
        cd: /var/www/october
        cmd:
          - sudo -u october composer require rainlab/blog-plugin
```

### Available Templates

| Template | Purpose |
|----------|---------|
| `mysql.template.yml` | MySQL database server |
| `redis.template.yml` | Redis for cache/sessions/queues |
| `web.template.yml` | Apache + PHP + October CMS |
| `web.ssl.template.yml` | SSL/HTTPS configuration |
| `web.letsencrypt.template.yml` | Automatic Let's Encrypt |
| `scheduler.template.yml` | Laravel scheduler (cron) |
| `queue.template.yml` | Queue workers |

### Sample Configurations

| Sample | Description |
|--------|-------------|
| `standalone.yml` | All-in-one with MySQL, Redis, web |
| `standalone-dev.yml` | Development setup with Xdebug |
| `web-only.yml` | Web container only (external DB) |
| `data.yml` | Data container (MySQL + Redis only) |

## Template System

Templates use a YAML-based configuration language with support for:

### Variables

```yaml
params:
  db_name: october
  php_memory_limit: 256M

env:
  DB_DATABASE: $db_name
```

### Run Steps

```yaml
run:
  # Execute commands
  - exec:
      cmd: echo "Hello"

  # Execute in directory
  - exec:
      cd: /var/www/october
      cmd:
        - composer install
        - php artisan migrate

  # Create files
  - file:
      path: /etc/php.ini
      contents: |
        memory_limit = 256M

  # Replace text
  - replace:
      filename: /etc/apache2/apache2.conf
      from: "Timeout 60"
      to: "Timeout 300"
```

### Hooks

```yaml
hooks:
  before_code:
    - exec: echo "Before cloning code"
  after_code:
    - exec: composer install
  after_migrate:
    - exec: php artisan cache:clear
```

## Development Mode

For development with Xdebug:

```bash
# Use the dev sample configuration
cp samples/standalone-dev.yml containers/dev.yml
./launcher bootstrap dev
```

The development image includes:
- Xdebug with step debugging
- Development PHP settings
- Node.js for frontend builds
- SQLite for testing

## SSL/HTTPS

### Let's Encrypt (Automatic)

Add these templates to your configuration:

```yaml
templates:
  - "templates/web.template.yml"
  - "templates/web.ssl.template.yml"
  - "templates/web.letsencrypt.template.yml"

env:
  LETSENCRYPT_EMAIL: "admin@example.com"
```

### Custom Certificate

Place your certificate files in `/var/october/shared/app/ssl/`:
- `cert.pem` - Certificate
- `key.pem` - Private key
- `chain.pem` - Certificate chain

Then add:

```yaml
templates:
  - "templates/web.template.yml"
  - "templates/web.ssl.template.yml"
```

## Plugins and Themes

Install plugins via hooks in your configuration:

```yaml
hooks:
  after_composer:
    - exec:
        cd: /var/www/october
        cmd:
          - sudo -u october composer require rainlab/blog-plugin
          - sudo -u october composer require rainlab/user-plugin
```

Or install via the container:

```bash
./launcher enter app
php artisan plugin:install RainLab.Blog
```

## Updating

To update October CMS:

```bash
./launcher rebuild app
```

This will:
1. Pull the latest code from the configured repository
2. Run composer install
3. Run database migrations
4. Clear and rebuild caches

## Backups

The `shared/` directory contains all persistent data:

```bash
# Backup
tar -czvf backup-$(date +%Y%m%d).tar.gz shared/app/

# Restore
tar -xzvf backup-20231215.tar.gz
./launcher rebuild app
```

## Troubleshooting

Run the doctor tool to diagnose issues:

```bash
./october-doctor app
```

Common issues:

### Container won't start
```bash
./launcher logs app        # Check logs
./october-doctor app       # Run diagnostics
```

### Permission issues
```bash
./launcher enter app
chown -R october:www-data /var/www/october/storage
chmod -R 775 /var/www/october/storage
```

### Database connection failed
Check your `containers/app.yml` for correct database credentials:
```yaml
env:
  DB_HOST: "127.0.0.1"
  DB_DATABASE: october
  DB_USERNAME: october
  DB_PASSWORD: "your-password"
```

## How It Works

This project follows tooling (launcher, setup wizard, doctor) is written in Bash and requires only Docker on the host machine.

YAML configuration parsing is performed by running PHP inside a Docker container, piping the configuration file to the container for processing. This approach means:

- **No PHP installation required on host**
- **No Composer or dependencies on host**
- **Works on any system with Bash and Docker**
