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
  - command: echo hello world
    label: run container with links that fail
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: alpinewithfailinglink
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: build
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run after build
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: build with image name
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworldimage
        config: test/docker-compose.yml
  - wait
  - command: /hello
    label: run after build with image name
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworldimage
        config: test/docker-compose.yml
  - command: /hello
    label: run after build with image name and logs
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworldimage
        config: test/docker-compose.yml
YAML