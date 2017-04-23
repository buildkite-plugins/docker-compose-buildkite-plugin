#!/bin/bash

set -eu

# If you build HEAD the pipeline.sh step, because it runs first, won't yet
# have the updated commit SHA. So we have to figure it out ourselves.
if [[ "${BUILDKITE_COMMIT:-HEAD}" == "HEAD" ]]; then
  commit=$(git show HEAD -s --pretty='%h')
else
  commit="${BUILDKITE_COMMIT}"
fi

# We have to use cat because pipeline.yml $ interpolation doesn't work in YAML
# keys, only values

cat <<YAML
steps:
  - label: run bats tests
    command: tests/lib tests/commands
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: tests

  - wait
  - label: run, with links that fail
    command: echo hello from alpine
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: alpinewithfailinglink
        config: tests/composefiles/docker-compose.yml

  - wait
  - label: build
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworld
        config: tests/composefiles/docker-compose.yml

  - wait
  - label: run after build
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: tests/composefiles/docker-compose.yml

  - wait
  - label: build, where an image name is specified
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworldimage
        config: tests/composefiles/docker-compose.yml

  - wait
  - label: run after build with image name specified
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworldimage
        config: tests/composefiles/docker-compose.yml

YAML