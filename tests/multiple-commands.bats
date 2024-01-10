#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/metadata'

# export DOCKER_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

setup_file() {
  # General pipeline variables
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="pwd"
  export BUILDKITE_JOB_ID=12
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN_LABELS="false"
}

teardown() {
  # some test failures may leave this file around
  rm -f docker-compose.buildkite-1-override.yml
}

@test "Build and run" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  
  # necessary for build
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite12 build --pull myservice : echo built myservice" \
    "compose -f docker-compose.yml -p buildkite12 up -d --scale myservice=0 myservice : echo ran dependencies" \
    "compose -f docker-compose.yml -p buildkite12 run --name buildkite12_myservice_build_1 -T --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : test -f /tmp/build-run-metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Building services myservice"
  assert_output --partial "Starting dependencies"
  assert_output --partial "ran myservice" 

  unstub docker
  unstub buildkite-agent
}

@test "Build and push" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  # necessary for build
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite12 build --pull myservice : echo built myservice" \
    "compose -f docker-compose.yml -p buildkite12 config : echo ''" \
    "image inspect buildkite12_myservice : echo existing-image" \
    "compose -f docker-compose.yml -p buildkite12 push myservice : echo pushed myservice"
  
  # these commands simulate metadata for a specific value by using an intermediate-file
  stub buildkite-agent \
     "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4 > /tmp/build-push-metadata"

  run "$PWD"/hooks/command

  assert_success

  assert_output --partial "Building services myservice"
  assert_output --partial "Using service image buildkite12_myservice from Docker Compose config"
  assert_output --partial "Pushing images for myservice"

  unstub docker
  unstub buildkite-agent
}

@test "Run and push without pre-built image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  stub docker \
    "compose -f docker-compose.yml -p buildkite12 up -d --scale myservice=0 myservice : echo ran dependencies" \
    "compose -f docker-compose.yml -p buildkite12 run --name buildkite12_myservice_build_1 -T --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice" \
    "compose -f docker-compose.yml -p buildkite12 config : echo ''" \
    "image inspect buildkite12_myservice : exit 1"
  
  # these make sure that the image is not pre-built
  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_failure

  assert_output --partial "No pre-built image found from a previous "
  assert_output --partial "Starting dependencies"
  assert_output --partial "ran myservice" 
  assert_output --partial "No prebuilt-image nor service image found for service to push"

  unstub docker
  unstub buildkite-agent
}

@test "Run and push without pre-built image with service image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  stub docker \
    "compose -f docker-compose.yml -p buildkite12 up -d --scale myservice=0 myservice : echo ran dependencies" \
    "compose -f docker-compose.yml -p buildkite12 run --name buildkite12_myservice_build_1 -T --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice" \
    "compose -f docker-compose.yml -p buildkite12 config : echo ''" \
    "image inspect \* : echo found image \$3" \
    "compose -f docker-compose.yml -p buildkite12 push myservice : echo pushed myservice"

  # these make sure that the image is not pre-built
  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : set pre-built image metadata to \$4"

  run "$PWD"/hooks/command

  assert_success

  assert_output --partial "No pre-built image found from a previous "
  assert_output --partial "Starting dependencies"
  assert_output --partial "ran myservice" 
  assert_output --partial "Using service image"

  unstub docker
  unstub buildkite-agent
}

@test "Run and push with pre-built image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  stub docker \
    "compose -f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "compose -f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran dependencies" \
    "compose -f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml run --name buildkite12_myservice_build_1 -T --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice" \
    "compose -f docker-compose.yml -p buildkite12 config : echo ''" \
    "image inspect buildkite12_myservice : exit 1" \
    "pull myservice-tag : echo pulled pre-built image" \
    "compose -f docker-compose.yml -p buildkite12 push myservice : echo pushed myservice"
  
  # these make sure that the image is not pre-built
  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myservice-tag" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myservice-tag" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : set pre-built image metadata to \$4"

  run "$PWD"/hooks/command

  assert_success

  refute_output --partial "Building services myservice"
  assert_output --partial "Found a pre-built image for myservice"
  assert_output --partial "Pulling services myservice"
  assert_output --partial "Starting dependencies"
  assert_output --partial "Pulling pre-built service myservice"
  assert_output --partial "Pushing images for myservice" 

  unstub docker
  unstub buildkite-agent
}
