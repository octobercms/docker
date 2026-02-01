# October CMS Docker

Docker-based deployment for October CMS with a simple CLI interface.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/october-docker.git
cd october-docker/october

# Set up a new site
./october-setup myapp

# Start the site
./launcher start myapp
```

Your site will be available at http://localhost

## Requirements

- Docker Engine 20.10+
- Docker Compose v2

## Architecture

```
october-docker/                    # This repository (clone once)
├── containers/                    # Site configurations
│   └── myapp.yml
├── docker/                        # Docker infrastructure
│   └── web/
│       ├── Dockerfile
│       └── ...
├── launcher                       # CLI tool
├── october-setup                  # Setup wizard
└── docker-compose.base.yml

~/october-sites/myapp/             # Your site files
├── .env                           # Environment variables
├── .data/                         # Database & Redis data
│   ├── mysql/
│   └── redis/
├── artisan                        # October CMS files
├── composer.json
└── ...
```

## Commands

| Command | Description |
|---------|-------------|
| `./october-setup <name>` | Create a new site configuration |
| `./launcher start <name>` | Start containers |
| `./launcher stop <name>` | Stop containers |
| `./launcher restart <name>` | Restart containers |
| `./launcher rebuild <name>` | Rebuild and restart (after Dockerfile changes) |
| `./launcher enter <name>` | Open shell in web container |
| `./launcher logs <name>` | View container logs |
| `./launcher status` | Show all sites and their status |
| `./launcher destroy <name>` | Remove containers (preserves data) |

## Setup Options

### Development Environment

- Xdebug enabled for debugging
- APP_DEBUG=true
- OPcache validates timestamps
- Bundled MariaDB and Redis

### Production Environment

- Xdebug disabled
- APP_DEBUG=false
- OPcache optimized
- SSL via Let's Encrypt or custom certificates
- Option to use external database (AWS RDS) and Redis (ElastiCache)

## Multi-Site Setup

Run multiple October sites from one installation:

```bash
./october-setup blog
./october-setup shop --port 8080
./october-setup corporate --port 8081

./launcher start blog
./launcher start shop
./launcher start corporate
```

Each site has isolated containers and data directories.

## VS Code Development

For the best development experience, use VS Code with Dev Containers:

1. Start your site: `./launcher start myapp`
2. Open VS Code
3. Install "Dev Containers" extension
4. Open the site folder (`~/october-sites/myapp`)
5. Click "Reopen in Container"

This gives you:
- Full IDE with IntelliSense
- Integrated debugging with Xdebug
- Terminal access inside the container
- Fast file access (no bind mount penalty)

## Custom Git Repository

To deploy from your own October CMS repository instead of a fresh install:

1. During setup, select "Yes" for custom Git repository
2. Enter your repository URL
3. The entrypoint will clone your repo and run `composer install`

Or manually set `OCTOBER_REPO` in your site's `.env` file before first start.

## Configuration Files

### Site Configuration (`containers/<name>.yml`)

```yaml
environment: development
site_path: ~/october-sites/myapp
http_port: 80

services:
  mariadb: true
  redis: true
```

### Environment Variables (`~/october-sites/<name>/.env`)

Generated automatically by `october-setup`. Contains:
- APP_KEY, APP_URL, APP_ENV
- Database credentials
- Redis configuration

## Stack

- **PHP**: 8.3 with FPM
- **Web Server**: Apache with HTTP/2
- **Database**: MariaDB 10.11
- **Cache**: Redis 7
- **Process Manager**: Supervisor

## Troubleshooting

### Container won't start

```bash
./launcher logs myapp
```

### Database connection issues

Check that MariaDB is healthy:
```bash
docker ps
```

The web container waits for MariaDB to be ready before running migrations.

### Permission issues

The container runs as `www-data`. If you have permission issues with mounted files:

```bash
./launcher enter myapp
chown -R www-data:www-data /var/www/html/storage
```

### Reset everything

```bash
./launcher destroy myapp
rm -rf ~/october-sites/myapp
./october-setup myapp
./launcher start myapp
```

## License

MIT
