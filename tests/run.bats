#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

@test "Run without a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 myservice echo hello world : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : exit 1"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with a complicated command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="sh -c 'echo hello world; pwd'"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 myservice $BUILDKITE_COMMAND : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : exit 1"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with custom env" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENV_0=MYENV=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENV_1=MYENV
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENVIRONMENT_0=MYENV=2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENVIRONMENT_1=MYENV

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -e MYENV=0 -e MYENV -e MYENV=2 -e MYENV myservice pwd : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : exit 1"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 myservice pwd : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a single prebuilt image, no retry on failed pull" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : exit 2"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "Exited with 2"
  unstub docker-compose
  unstub buildkite-agent
}


@test "Run with a single prebuilt image, retry on failed pull" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_RETRIES=3

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : exit 2" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 myservice pwd : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}
