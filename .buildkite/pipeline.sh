#!/bin/bash

set -eu

# We have to use cat because pipeline.yml $ interpolation doesn't work in YAML
# keys, only values

cat <<YAML
steps:
  - command: /hello
    label: run
    plugins:
      docker-compose#${BUILDKITE_COMMIT}:
        run: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: build
    plugins:
      docker-compose#${BUILDKITE_COMMIT}:
        build: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run after build
    plugins:
      docker-compose#${BUILDKITE_COMMIT}:
        run: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: build with image name
    plugins:
      docker-compose#${BUILDKITE_COMMIT}:
        build: helloworldimage
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run after build with image name
    plugins:
      docker-compose#${BUILDKITE_COMMIT}:
        run: helloworldimage
        config: test/docker-compose.yml
  - command: /hello
    label: run after build with image name and logs
    plugins:
      docker-compose#${BUILDKITE_COMMIT}:
        run: helloworldimage
        config: test/docker-compose.yml
        logs: true
YAML