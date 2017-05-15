#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

setup() {
  if [[ -f docker-compose.buildkite-1-override.yml ]]; then
    rm docker-compose.buildkite-1-override.yml
  fi
}

@test "Push a single image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 0"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 push myservice : echo pushed myservice"

  run $PWD/hooks/command

  assert_success
  assert_file_not_exist "docker-compose.buildkite-1-override.yml"
  assert_output --partial "pushed myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Push two images with a repository and a tag" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice1:my.repository/myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice2:my.repository/myservice2:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice1 myservice2 : echo pushed myservices"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 0"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pushed myservices"
  assert_file_exist "docker-compose.buildkite-1-override.yml"
  assert grep -q "image: my.repository/myservice1" docker-compose.buildkite-1-override.yml
  assert grep -q "image: my.repository/myservice2:llamas" docker-compose.buildkite-1-override.yml
  unstub docker-compose
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "tag myimage:blahblah my.repository/myservice:llamas : echo tagged image"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled prebuilt image" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 1" \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo myservice" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage:blahblah"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"
  assert_file_exist "docker-compose.buildkite-1-override.yml"
  assert grep -q "image: my.repository/myservice:llamas" docker-compose.buildkite-1-override.yml
  unstub docker-compose
  unstub docker
  unstub buildkite-agent
}