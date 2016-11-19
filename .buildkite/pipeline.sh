#!/bin/bash

set -eu

# pipeline.yml $ interpolation doesn't work in YAML keys, only values
PLUGIN="${BUILDKITE_BUILD_CHECKOUT_PATH}#${BUILDKITE_COMMIT}"

cat <<YAML
steps:
  - command: /hello
    label: run
    plugins:
      "$PLUGIN":
        run: helloworld
        config: .buildkite/docker-compose.yml
  - wait
  - command: /hello
    label: build
    plugins:
      "$PLUGIN":
        build: helloworld
        config: .buildkite/docker-compose.yml
  - wait
  - command: /hello
    label: run after build
    plugins:
      "$PLUGIN":
        run: helloworld
        config: .buildkite/docker-compose.yml
YAML