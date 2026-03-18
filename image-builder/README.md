# October CMS Image Builder

Builds and publishes the **octobercms/october** all-in-one Docker image.

This image contains October CMS with an embedded MariaDB 10.11 server — ready to run
with a single `docker run` command. It is designed for quick evaluation and
standalone deployments.

> **Note:** This image is separate from the CLI tool (`launcher` / `october-setup`)
> which creates multi-container development environments. See the root README for
> CLI tool documentation.

## Prerequisites

- Docker Engine (running, with push access to the target Docker Hub repo)

## Building

The Dockerfile uses a multi-stage build — no external scripts or tools required.

```bash
cd image-builder
docker build -t octobercms/october:latest .
```

The first build takes 10-15 minutes (downloads composer packages). Subsequent builds
use the Docker cache and take 1-2 minutes.

## Publishing

Log in to Docker Hub and push:

```bash
docker login
docker push octobercms/october:latest
```

Or use the helper script to build and push in one step:

```bash
./publish.sh                              # Push to octobercms/october:latest
./publish.sh octobercms/october-staging   # Push to a staging image
```

## What the build does

1. **Stage 1 (builder):** Creates a fresh October CMS project via `composer create-project`, generates an APP_KEY, and cleans up auth/project files
2. **Stage 2 (runtime):** Copies the built application into a PHP 8.3 + Apache + MariaDB 10.11 image

## Image architecture

The output image (`octobercms/october:latest`) contains:

- **Base:** PHP 8.3 with Apache on Debian Bookworm
- **Database:** MariaDB 10.11 (pinned via official MariaDB repository)
- **October CMS:** Pre-installed, copied to `/var/www/html` on first boot
- **Ports:** 80 (HTTP), 3306 (MariaDB)
- **Volumes:**
  - `/var/www/html` — Application files (optional mount for persistence)
  - `/var/lib/october-mysql` — Database data (optional mount for persistence)

## Running the image

Quick start (no persistence):

```bash
docker run -d -p 8080:80 octobercms/october:latest
```

With persistent database:

```bash
docker run -d -p 8080:80 -v october-db:/var/lib/october-mysql octobercms/october:latest
```

With persistent files and database:

```bash
docker run -d -p 8080:80 \
  -v october-files:/var/www/html \
  -v october-db:/var/lib/october-mysql \
  octobercms/october:latest
```

## Troubleshooting

If Docker returns "Cannot connect to the Docker daemon", see:
https://stackoverflow.com/questions/44084846/cannot-connect-to-the-docker-daemon-on-macos

```bash
sudo ln -s ~/Library/Containers/com.docker.docker/Data/docker.raw.sock /var/run/docker.sock
```
