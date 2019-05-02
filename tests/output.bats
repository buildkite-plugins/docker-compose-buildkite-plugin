#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD


@test "Detect some failed containers" {
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RM=false


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1" \
    "artifact upload : exit 0"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 myservice echo 'hello world' : echo ran myservice"

  stub docker \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 -q : echo 123123" \
    "inspect -f {{if\ ne\ 0\ .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{\ end\ }} 123123 : echo 123123.1" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format : echo 123123 1" \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 --format : echo 123123 myservice" \
    "inspect --format={{.State.ExitCode}} 123123\ myservice : echo 1" \
    "logs : exit 0" \
    "logs : exit 0"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  assert_output --partial "Some containers had non-zero exit codes"
  assert_output --partial "123123 1"
  unstub buildkite-agent
  unstub docker-compose
  unstub docker
}

@test "Detect no failed containers" {
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RM=false


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 myservice echo 'hello world' : echo ran myservice"

  stub docker \
    "ps -a --filter label=com.docker.compose.project=buildkite1111 -q : echo 123123" \
    "inspect -f {{if\ ne\ 0\ .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{\ end\ }} 123123 : " \
    "ps -a --filter : echo myservice 123123 0" \
    "inspect --format={{.State.ExitCode}} myservice\ 123123\ 0 : echo 0"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  refute_output --partial "Some containers had non-zero exit codes"
  refute_output --partial "123123 1"
  unstub docker
  unstub docker-compose
  unstub buildkite-agent
}

@test "Failed containers are not attempted to be output if removed first" {
  export BUILDKITE_AGENT_ACCESS_TOKEN="123123"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RM=true


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice echo 'hello world' : echo ran myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  assert_output --partial "Can't check linked containers when 'rm' is enabled"
  refute_output --partial "Some containers had non-zero exit codes"
  refute_output --partial "123123 1"
  unstub docker-compose
  unstub buildkite-agent
}
