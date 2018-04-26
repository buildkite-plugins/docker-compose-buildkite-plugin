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
  - label: ":shell: Shellcheck"
    plugins:
      shellcheck#v1.0.0:
        files: hooks/**

  - label: ":shell: Lint"
    plugins:
      plugin-linter#v1.0.0:
        name: docker-compose

  - label: run bats tests
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: tests

  - wait
  - label: run, with links that fail
    command: echo hello from alpine
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: alpinewithfailinglink
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: run, with environment
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: alpinewithenv
        config: tests/composefiles/docker-compose.v2.1.yml
        environment:
          - ALPACAS=sometimes


  - wait
  - label: build
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworld
        image-repository: buildkiteci/docker-compose-buildkite-plugin
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: run after build with v2.0
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: tests/composefiles/docker-compose.v2.0.yml

  - wait
  - label: run after build with v2.1
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: run with default command
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: build, where serice has build and image-name
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworldimage
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: run after build
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworldimage
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: build with custom image-name
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        build: helloworld
        image-repository: buildkiteci/docker-compose-buildkite-plugin
        image-name: llamas-build-${BUILDKITE_BUILD_NUMBER}
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: run after build with custom image-name
    command: /hello
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        run: helloworld
        config: tests/composefiles/docker-compose.v2.1.yml

  - wait
  - label: push after build with custom image-name
    plugins:
      ${BUILDKITE_REPO}#${commit}:
        push: helloworld
        config: tests/composefiles/docker-compose.v2.1.yml

YAML
