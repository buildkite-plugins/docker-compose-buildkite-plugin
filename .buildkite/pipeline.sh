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
    command: bats test
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: bats
        config: test/docker-compose.bats.yml

  - wait
  - label: run, with links that fail
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: alpinewithfailinglink
        config: test/docker-compose.yml

  - wait
  - label: build
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworld
        config: test/docker-compose.yml

  - wait
  - label: run after build
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: test/docker-compose.yml

  - wait
  - label: build, where an image name is specified
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworldimage
        config: test/docker-compose.yml

  - wait
  - label: run after build with image name specified
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworldimage
        config: test/docker-compose.yml

YAML