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

## Installing October CMS v3

To install October CMS v3 from the official repository:

```bash
# Set up a new site
./october-setup myapp
```

During setup, select **"Yes"** for custom Git repository and enter:
- **Repository URL**: `https://github.com/octobercms/october.git`
- **Branch**: `3.x`

Then start the site:

```bash
./launcher start myapp
```

On first start, the container will clone the repository, check out the `3.x` branch, and run `composer install`. Once the containers are running, open a shell to complete the installation:

```bash
./launcher enter myapp
php artisan october:install
php artisan october:migrate
php artisan october:mirror
```

This will run the interactive installer where you can enter your license key and configure the application. You only need to do this once.

## Requirements

- Docker Engine 20.10+
- Docker Compose v2
- WSL2 (Windows) or native Linux/macOS

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
| `./launcher code <name>` | Open VS Code attached to the web container |
| `./launcher status` | Show all sites and their status |
| `./launcher destroy <name>` | Remove containers (preserves data) |
| `./launcher wipe <name>` | Completely remove a site (containers, files, config) |
| `./launcher mount` | Share sites via Samba and mount as a Windows drive (WSL only) |
| `./launcher unmount` | Disconnect the Windows drive and stop Samba (WSL only) |

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

Open VS Code attached to a running site container:

```bash
./launcher code myapp
```

This opens VS Code with the Dev Containers extension connected directly to the web container, giving you:
- Full IDE with IntelliSense
- Integrated debugging with Xdebug
- Terminal access inside the container

## Windows Development (WSL)

On Windows, site files live inside WSL2 for optimal Docker volume performance. To access them with Windows tools like Tortoise Git, the launcher can mount the sites directory as a Windows drive via Samba:

```bash
./launcher mount
```

This will:
1. Install Samba in WSL if needed (one-time)
2. Configure a share for `~/october-sites`
3. Ask for a drive letter (default: Z)
4. Mount the drive automatically

Your sites will be available at `Z:\myapp`, `Z:\blog`, etc. Use Tortoise Git, Explorer, and other Windows tools normally.

To disconnect:

```bash
./launcher unmount
```

The WSL IP changes on reboot, so you'll need to run `./launcher mount` each time you restart your machine.

## Custom Git Repository

To deploy from your own October CMS repository instead of a fresh install:

1. During setup, select "Yes" for custom Git repository
2. Enter your repository URL
3. Optionally specify a branch (leave empty for the default branch)
4. The entrypoint will clone your repo and run `composer install`

Or manually set `OCTOBER_REPO` and `OCTOBER_BRANCH` in your site's `.env` file before first start.

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

### Windows drive is read-only or shows permission errors

If accessing files via `\\wsl.localhost\` or a mapped drive shows permission errors, use the Samba mount instead:

```bash
./launcher mount
```

Samba bypasses Linux file permissions, so files are always writable regardless of ownership.

### Phantom drives after unmount

If a mapped drive letter persists in Explorer after unmounting, restart Explorer:

```powershell
Stop-Process -Name explorer -Force; Start-Process explorer
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
