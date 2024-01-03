#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/metadata'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
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

@test "Build and run" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  
  # necessary for build
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas

  stub docker-compose \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran dependencies" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml run --name buildkite12_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  # these commands simulate metadata for a specific value by using an intermediate-file
  stub buildkite-agent \
     "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4 > /tmp/build-run-metadata" \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : test -f /tmp/build-run-metadata" \
     "meta-data get docker-compose-plugin-built-image-tag-myservice : cat /tmp/build-run-metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Building services myservice"
  assert_output --partial "Pushing built images to my.repository/llamas"
  assert_output --partial "Found a pre-built image for myservice"
  assert_output --partial "Starting dependencies"
  assert_output --partial "ran myservice" 

  unstub docker-compose
  unstub buildkite-agent
}

@test "Build and push" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  # necessary for build
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas

  stub docker-compose \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml push myservice : echo build-pushed myservice" \
     "-f docker-compose.yml -p buildkite12 config : echo ''" \
     "-f docker-compose.yml -p buildkite12 push myservice : echo push-pushed myservice"
  
  # these commands simulate metadata for a specific value by using an intermediate-file
  stub buildkite-agent \
     "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4 > /tmp/build-push-metadata" \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : test -f /tmp/build-push-metadata" \
     "meta-data get docker-compose-plugin-built-image-tag-myservice : cat /tmp/build-push-metadata"

  stub docker \
     "pull my.repository/llamas:test-myservice-build-1 : echo pulled pre-built image" \
     "tag my.repository/llamas:test-myservice-build-1 buildkite12_myservice : echo re-tagged pre-built image"

  run "$PWD"/hooks/command

  assert_success

  assert_output --partial "Building services myservice"
  assert_output --partial "Pushing built images to my.repository/llamas"
  assert_output --partial "Pulling pre-built service myservice"
  assert_output --partial "Tagging pre-built service myservice"
  assert_output --partial "Pushing images for myservice"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run and push without pre-built image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  stub docker-compose \
     "-f docker-compose.yml -p buildkite12 build --pull myservice : echo built myservice" \
     "-f docker-compose.yml -p buildkite12 up -d --scale myservice=0 myservice : echo ran dependencies" \
     "-f docker-compose.yml -p buildkite12 run --name buildkite12_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice" \
     "-f docker-compose.yml -p buildkite12 config : echo ''" \
     "-f docker-compose.yml -p buildkite12 build myservice : echo built-2 myservice" \
     "-f docker-compose.yml -p buildkite12 push myservice : echo pushed myservice"
  
  # these make sure that the image is not pre-built
  stub buildkite-agent \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success

  assert_output --partial "Building Docker Compose Service: myservice"
  assert_output --partial "No pre-built image found from a previous "
  assert_output --partial "Starting dependencies"
  assert_output --partial "ran myservice" 
  assert_output --partial "Building myservice"
  assert_output --partial "Pushing images for myservice"

  unstub docker-compose
  unstub buildkite-agent
}


@test "Run and push with pre-built image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice

  stub docker-compose \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran dependencies" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml run --name buildkite12_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice" \
     "-f docker-compose.yml -p buildkite12 config : echo ''" \
     "-f docker-compose.yml -p buildkite12 push myservice : echo pushed myservice"
  
  # these make sure that the image is not pre-built
  stub buildkite-agent \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
     "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myservice-tag" \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
     "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myservice-tag"

  stub docker \
     "pull myservice-tag : echo pulled pre-built image" \
     "tag myservice-tag buildkite12_myservice : echo re-tagged pre-built image"

  run "$PWD"/hooks/command

  assert_success

  refute_output --partial "Building services myservice"
  assert_output --partial "Found a pre-built image for myservice"
  assert_output --partial "Pulling services myservice"
  assert_output --partial "Starting dependencies"
  assert_output --partial "Pulling pre-built service myservice"
  assert_output --partial "Pushing images for myservice" 

  unstub docker-compose
  unstub buildkite-agent
}

