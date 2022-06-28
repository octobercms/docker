#!/bin/bash

imageName="octobercms/october-dev:latest"

if ! [ -d octobercms-database ]; then
    echo "Creating the octobercms-database directory to store the MySQL files."
    mkdir octobercms-database
else
    echo "The octobercms-database directory already exists, we will use it."
fi

if ! [ -d octobercms-files ]; then
    echo "Creating the octobercms-files directory to store October CMS files."
    mkdir octobercms-files
else
    echo "The octobercms-files directory already exists, we will use it."
fi

echo "Enter a TCP port number for accessing the application in a browser. Leave empty to use the default port 8080."

while true; do
    echo -n "http://localhost:"
    read port

    if [[ $port =~ ^[0-9]*$ ]]; then
        break
    else
        echo "Please enter a number or leave the value empty to use 8080."
        continue
    fi
done

if [ -z "$port" ]; then
    port=8080
fi

echo "Enter a TCP port number for accessing the MySQL server running in the container. Leave empty to use the default port 3333."

while true; do
    echo -n "MySQL port: "
    read mysqlPort

    if [[ $mysqlPort =~ ^[0-9]*$ ]]; then
        break
    else
        echo "Please enter a number or leave the value empty to use 3333."
        continue
    fi
done

if [ -z "$mysqlPort" ]; then
    mysqlPort=3333
fi

echo "Enter the container name. Leave empty to use the default value \"octobercms-dev\"."

while true; do
    echo -n "Container name: "
    read containerName

    if [[ $containerName =~ ^[a-zA-Z0-9\_\-]*$ ]]; then
        if ! [ -z "$containerName" ] && [ "$(docker ps -a -f name="$containerName" | grep -w "$containerName")" ]; then
            echo "The container name is already in use, please enter another name or leave empty to use the default value \"octobercms-dev\"."
            continue;
        fi

        break
    else
        echo "The container name can contain only digits, Latin letters, underscores and dashes."
        continue
    fi
done

if [ -z "$containerName" ]; then
    containerName="octobercms-dev"
    counter=1
    while [ "$(docker ps -a -f name="$containerName" | grep -w "$containerName")" ]; do
        containerName="octobercms-dev-${counter}"

        counter=`expr $counter + 1`
    done

    if [ "$counter" -gt 1 ]; then
        echo "The container name octobercms-dev is already in use. We will use ${containerName} for this installation."
    fi
fi

echo "Pulling the latest October CMS Dev docker image..."
docker pull $imageName

echo "Creating the container..."
filesDirPath="${PWD}/octobercms-files"
dataDirPath="${PWD}/octobercms-database"

docker run -d --name $containerName -p $port:80 -p $mysqlPort:3306 -v $dataDirPath:/var/lib/october-mysql -v $filesDirPath:/var/www/html -it $imageName
if [ $? -ne 0 ]; then
    exit 1
fi

echo "Configuring the container. It can take several minutes."
while true; do
    curl -o /dev/null -s http://localhost:$port
    status=$?
    if [ $status -eq 0 ]; then
        break
    fi

    echo -n "."
    sleep 1
done

echo ""
echo ""

echo "The container has been successfully created and started."
echo "Installation URL: http://localhost:$port"
echo "Platform files: $filesDirPath"
echo "MySQL command to access the database: mysql --host=127.0.0.1 --user=root --password=root --port=$mysqlPort octobercms"
echo "Container name: $containerName"
