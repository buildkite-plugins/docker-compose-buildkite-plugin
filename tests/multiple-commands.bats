#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

 export DOCKER_COMPOSE_STUB_DEBUG=/dev/stdout
 export BUILDKITE_AGENT_STUB_DEBUG=/dev/stdout
# export BATS_MOCK_TMPDIR=$PWD


@test "Build and run in a single step" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --rm myservice /bin/sh -e -c echo hello world : echo ran myservice"
  
  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/llamas:test-myservice-build-1 : echo set meta-data" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : echo meta-data exists"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  
  #unstub docker-compose
  #unstub buildkite-agent
}





