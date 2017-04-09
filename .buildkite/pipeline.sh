#!/bin/bash

set -eu

if [[ "${SELF_TEST:-false}" == "true" ]]; then
  plugin="$(pwd)"
else
  plugin="docker-compose"
fi

# We have to use cat because pipeline.yml $ interpolation doesn't work in YAML
# keys, only values

cat <<YAML
steps:
  - command: echo hello world
    label: run container with links that fail
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        run: alpinewithfailinglink
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        run: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: build
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        build: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run after build
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        run: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: build with image name
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        build: helloworldimage
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run after build with image name
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        run: helloworldimage
        config: test/docker-compose.yml
  - command: /hello
    label: run after build with image name and logs
    plugins:
      ${plugin}#${BUILDKITE_COMMIT}:
        run: helloworldimage
        config: test/docker-compose.yml

YAML