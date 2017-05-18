#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

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
    "-f docker-compose.yml -p buildkite1111 config : echo blah " \
    "-f docker-compose.yml -p buildkite1111 config : echo blah "

  stub docker \
    "tag buildkite1111_myservice1 my.repository/myservice1 : echo tagging image1" \
    "push my.repository/myservice1 : echo pushing myservice1 image" \
    "tag buildkite1111_myservice2 my.repository/myservice2:llamas : echo tagging image2" \
    "push my.repository/myservice2:llamas : echo pushing myservice2 image"


  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 0"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "tagging image1"
  assert_output --partial "pushing myservice1 image"
  assert_output --partial "tagging image2"
  assert_output --partial "pushing myservice2 image"
  unstub docker-compose
  unstub buildkite-agent
  unstub docker
}

@test "Push a prebuilt image with a repository and a tag" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "pull myimage:blahblah : echo pulled prebuilt image" \
    "tag myimage:blahblah buildkite1111_myservice : echo " \
    "tag buildkite1111_myservice my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo blah" \
    "-f docker-compose.yml -p buildkite1111 config : echo blah"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 1" \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo myservice" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage:blahblah"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"
  unstub docker-compose
  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image to multiple tags" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice:my.repository/myservice:llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice:my.repository/myservice:latest
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_2=myservice:my.repository/myservice:alpacas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "pull myimage:blahblah : echo pulled prebuilt image" \
    "tag myimage:blahblah buildkite1111_myservice : echo " \
    "tag buildkite1111_myservice my.repository/myservice:llamas : echo tagged image1" \
    "push my.repository/myservice:llamas : echo pushed myservice1" \
    "tag buildkite1111_myservice my.repository/myservice:latest : echo tagged image2" \
    "push my.repository/myservice:latest : echo pushed myservice2" \
    "tag buildkite1111_myservice my.repository/myservice:alpacas : echo tagged image3" \
    "push my.repository/myservice:alpacas : echo pushed myservice3"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo blah" \
    "-f docker-compose.yml -p buildkite1111 config : echo blah" \
    "-f docker-compose.yml -p buildkite1111 config : echo blah" \
    "-f docker-compose.yml -p buildkite1111 config : echo blah"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 1" \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo myservice" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage:blahblah"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image1"
  assert_output --partial "pushed myservice1"
  assert_output --partial "tagged image2"
  assert_output --partial "pushed myservice2"
  assert_output --partial "tagged image3"
  assert_output --partial "pushed myservice3"
  unstub docker-compose
  unstub docker
  unstub buildkite-agent
}