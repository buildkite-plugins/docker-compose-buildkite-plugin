#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

@test "Cleanup runs after a run command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 kill : echo killing containers" \
    "-f docker-compose.yml -p buildkite1111 rm --force -v : echo removing stopped containers" \
    "-f docker-compose.yml -p buildkite1111 down --volumes : echo removing everything"

  run $PWD/hooks/pre-exit

  assert_success
  assert_output --partial "Cleaning up after docker-compose"
  unstub docker-compose
}
