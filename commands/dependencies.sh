#!/bin/sh

cat <<'EOF' >|docker-compose.yaml
services:
  leaf:
    command: "true"
    depends_on:
      - root
    image: postgres:17beta2-bullseye
    network_mode: none

  root:
    command: "true"
    image: golang:1.22.5-bullseye
    network_mode: none
EOF

# shellcheck disable=SC2046
reset_docker() {
    docker stop $(docker ps -qa)
    docker rm $(docker ps -qa)
    docker rmi -f $(docker images -qa)
    docker volume rm $(docker volume ls -q)
    docker network rm $(docker network ls -q)
    docker builder prune -a -f
    docker system df
}

reset_docker >/dev/null 2>&1
time docker-compose run leaf

reset_docker >/dev/null 2>&1
time sh -c 'docker-compose pull --include-deps --quiet --parallel leaf; docker-compose run leaf'
