#!/bin/bash

echo "~~~ Building Docker Compose images for service ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD}"

run_docker_compose build "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"

echo "TODO: Store image"
