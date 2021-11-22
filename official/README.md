# Official Build

The official docker build acts as public image to quickly get started using October CMS. The application files are downloaded after the image is launched.

## Under Construction

**The official docker build is currently under development**. If you would like to see this feature, please add your comments to the roadmap item.

- [Docker Image for October CMS](https://portal.octobercms.com/c/33-docker-image-for-october-cms)

For now we recommend using the [custom build process](../custom).

## Quick Start

To run October CMS using Docker, start a container using the latest image, mapping your local port 80 to the container's port 80:

    $ docker run -p 80:80 --name october octobercms/october:latest
    # `CTRL-C` to stop
    $ docker rm october  # Destroys the container

If there is a port conflict, you will receive an error message from the Docker daemon. Try mapping to an open local port (`-p 8080:80`) or shut down the container or server that is on the desired port.

 - Visit [http://localhost](http://localhost) using your browser.
 - Login to the [backend](http://localhost/backend) and set up an administrator account
 - Hit `CTRL-C` to stop the container. Running a container in the foreground will send log outputs to your terminal.

Run the container in the background by passing the `-d` option:

    $ docker run -p 80:80 --name october -d octobercms/october:latest
    $ docker stop october  # Stops the container. To restart `docker start october`
    $ docker rm october  # Destroys the container
