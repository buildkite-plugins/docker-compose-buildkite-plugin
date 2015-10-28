#!/bin/bash

echo "~~~ Listing docker images"

buildkite-run "docker ps"
buildkite-run "docker images"

echo "~~~ Building Docker Compose images for service ${BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD}"

run_docker_compose build "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD"

echo "~~~ Listing docker images"

buildkite-run "docker ps"
buildkite-run "docker images"

echo "~~~ Storing image"

echo "TODO"
