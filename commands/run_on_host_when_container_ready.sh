#!/bin/bash
set -ueo pipefail

# TODO: Customize which files are copied to the container
echo "--- :docker: Waiting for the container to start before copying . into ${run_service}:/vydia/"

# Wait until the container is ready
while [ -z "$(docker-compose ps -q ${run_service})" ]; do
  printf "."
  sleep 1
done

echo "docker ps"
docker ps
container_id="$(run_docker_compose ps -q "${run_service}")"
echo "docker container_id: ${container_id}"
echo "docker cp"
docker cp . "${container_id}:/vydia/"
echo "Done cp"
