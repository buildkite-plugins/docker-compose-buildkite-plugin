#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/metadata'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

# General pipeline variables
export BUILDKITE_BUILD_NUMBER=1
export BUILDKITE_COMMAND="pwd"
export BUILDKITE_JOB_ID=12
export BUILDKITE_PIPELINE_SLUG=test


@test "Build and run in a single step" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran dependencies" \
     "-f docker-compose.yml -p buildkite12 -f docker-compose.buildkite-1-override.yml run --name buildkite12_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"
  
  stub buildkite-agent \
     "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/llamas:test-myservice-build-1 : echo set meta-data" \
     "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
     "meta-data get docker-compose-plugin-built-image-tag-myservice : echo got meta-data"

  run $PWD/hooks/command

  unstub docker-compose
  unstub buildkite-agent

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "pushed myservice"
  assert_output --partial "pulled myservice"
  assert_output --partial "ran dependencies"
  assert_output --partial "ran myservice" 
}



