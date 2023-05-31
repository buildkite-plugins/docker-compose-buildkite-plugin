#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../../lib/shared'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

setup_file() {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION=2
}

@test "Push a single service with an image in it's config" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=app
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-app : exit 1"

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : cat $PWD/tests/composefiles/docker-compose.config.v3.2.yml" \
    "image inspect somewhere.dkr.ecr.some-region.amazonaws.com/blah : exit 0" \
    "compose -f docker-compose.yml -p buildkite1111 push app : echo pushed app"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial ":warning: Skipping build"
  assert_output --partial "pushed app"
  unstub docker
  unstub buildkite-agent
}

@test "Push two services with target repositories and tags" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice1:my.repository/myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice2:my.repository/myservice2:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah " \
    "image inspect buildkite1111-myservice1 : exit 1" \
    "compose -f docker-compose.yml -p buildkite1111 build myservice1 : echo blah " \
    "tag buildkite1111-myservice1 my.repository/myservice1 : echo tagging image1" \
    "push my.repository/myservice1 : echo pushing myservice1 image" \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah " \
    "image inspect buildkite1111-myservice2 : exit 1" \
    "compose -f docker-compose.yml -p buildkite1111 build myservice2 : echo blah " \
    "tag buildkite1111-myservice2 my.repository/myservice2:llamas : echo tagging image2" \
    "push my.repository/myservice2:llamas : echo pushing myservice2 image"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice1 : exit 1" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice2 : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "tagging image1"
  assert_output --partial "pushing myservice1 image"
  assert_output --partial "tagging image2"
  assert_output --partial "pushing myservice2 image"
  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull myimage : echo pulled prebuilt image" \
    "tag myimage buildkite1111-myservice : echo " \
    "tag buildkite1111-myservice my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"
  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag in compatibility mode" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMPATIBILITY=true

  stub docker \
    "compose --compatibility -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull myimage : echo pulled prebuilt image" \
    "tag myimage buildkite1111_myservice : echo " \
    "tag buildkite1111_myservice my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"
  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with an invalid tag" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:-llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "pulled prebuilt image"
  refute_output --partial "tagged image"
  assert_output --partial "invalid tag"
  unstub docker
}

@test "Push a prebuilt image to multiple tags" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice:my.repository/myservice:llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice:my.repository/myservice:latest
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_2=myservice:my.repository/myservice:alpacas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull prebuilt : echo pulled prebuilt image" \
    "tag prebuilt buildkite1111-myservice : echo " \
    "tag buildkite1111-myservice my.repository/myservice:llamas : echo tagged image1" \
    "push my.repository/myservice:llamas : echo pushed myservice1" \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "tag prebuilt buildkite1111-myservice : echo " \
    "tag buildkite1111-myservice my.repository/myservice:latest : echo tagged image2" \
    "push my.repository/myservice:latest : echo pushed myservice2" \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "tag prebuilt buildkite1111-myservice : echo " \
    "tag buildkite1111-myservice my.repository/myservice:alpacas : echo tagged image3" \
    "push my.repository/myservice:alpacas : echo pushed myservice3"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image1"
  assert_output --partial "pushed myservice1"
  assert_output --partial "tagged image2"
  assert_output --partial "pushed myservice2"
  assert_output --partial "tagged image3"
  assert_output --partial "pushed myservice3"
  unstub docker
  unstub buildkite-agent
}

@test "Push a single service that needs to be built" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=helper:my.repository/helper:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-helper : exit 1"

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : cat $PWD/tests/composefiles/docker-compose.config.v3.2.yml" \
    "image inspect buildkite1111-helper : exit 1" \
    "compose -f docker-compose.yml -p buildkite1111 build helper : echo built helper" \
    "tag buildkite1111-helper my.repository/helper:llamas : echo tagged helper" \
    "push my.repository/helper:llamas : echo pushed helper"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built helper"
  assert_output --partial "tagged helper"
  assert_output --partial "pushed helper"
  unstub docker
  unstub buildkite-agent
}
