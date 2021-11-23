# Custom Build

The custom docker build acts as a template for rolling your own private docker image. The application is built up front but a license key is required at build time.

## Building this Image

Use the following command to build this image locally using your license key.

    docker build -t myoctober:latest . --build-arg LICENSE_KEY=<enter license key here>

## Quick Start

To run October CMS using Docker, start a container using the latest image, mapping your local port 80 to the container's port 80:

    $ docker run -p 80:80 --name october myoctober:latest
    # `CTRL-C` to stop
    $ docker rm october  # Destroys the container

If there is a port conflict, you will receive an error message from the Docker daemon. Try mapping to an open local port (`-p 8080:80`) or shut down the container or server that is on the desired port.

 - Visit [http://localhost](http://localhost) using your browser.
 - Login to the [backend](http://localhost/backend) and set up an administrator account
 - Hit `CTRL-C` to stop the container. Running a container in the foreground will send log outputs to your terminal.

Run the container in the background by passing the `-d` option:

    $ docker run -p 80:80 --name october -d myoctober:latest
    $ docker stop october  # Stops the container. To restart `docker start october`
    $ docker rm october  # Destroys the container

To gain shell access to your container:

    docker exec -it october bash
