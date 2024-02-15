#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../../lib/shared'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup_file() {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION=1
}

@test "Push a single service with an image in its config" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=app
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-app \* : echo setting metadata to \$4"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : cat ${PWD}/tests/composefiles/docker-compose.config.v3.2.yml" \
    "-f docker-compose.yml -p buildkite1111 push app : echo pushed app"

  stub docker \
    "image inspect \* : exit 0"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pushed app"

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
    "pull myimage : echo pulled prebuilt image" \
    "image inspect \* : exit 0" \
    "tag myimage my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo ''"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4 > ${BATS_TEST_TMPDIR}/build-push-metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"

  unstub docker-compose
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
    "pull myimage : echo pulled prebuilt image" \
    "image inspect myimage : exit 0" \
    "tag myimage my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"


  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4"

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
    "pull prebuilt : echo 'pulled prebuilt image'" \
    "image inspect \* : echo found image \$3" \
    "tag prebuilt \* : echo 'invalid tag'; exit 1"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo ''"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Pulling pre-built service"
  refute_output --partial "tagged image"
  assert_output --partial "invalid tag"

  unstub docker
  unstub docker-compose
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
    "pull prebuilt : echo pulled prebuilt image" \
    "image inspect \* : exit 0" \
    "tag prebuilt my.repository/myservice:llamas : echo tagged image1" \
    "push my.repository/myservice:llamas : echo pushed myservice1" \
    "image inspect \* : exit 0" \
    "tag prebuilt my.repository/myservice:latest : echo tagged image2" \
    "push my.repository/myservice:latest : echo pushed myservice2" \
    "image inspect \* : exit 0" \
    "tag prebuilt my.repository/myservice:alpacas : echo tagged image3" \
    "push my.repository/myservice:alpacas : echo pushed myservice3"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo ''" \
    "-f docker-compose.yml -p buildkite1111 config : echo ''" \
    "-f docker-compose.yml -p buildkite1111 config : echo ''"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4"

  run "$PWD"/hooks/command

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

@test "Push a single service without prebuilt nor service image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=helper:my.repository/helper:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-helper : exit 1"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo ''"

  run "$PWD"/hooks/command

  assert_failure

  assert_output --partial 'No prebuilt-image nor built image found for service to push'

  unstub docker-compose
  unstub buildkite-agent
}

@test "Push two services without pre-built nor service image (second one is never tried)" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice1:my.repository/myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice2:my.repository/myservice2:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo ''"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice1 : exit 1"

  run "$PWD"/hooks/command

  assert_failure

  assert_output --partial 'No prebuilt-image nor built image found for service to push'

  unstub docker-compose
  unstub buildkite-agent
}

@test "Push two pre-built services with target repositories and tags" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice1:my.repository/myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice2:my.repository/myservice2:llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : echo ''" \
    "-f docker-compose.yml -p buildkite1111 config : echo ''" \

  stub docker \
    "pull myservice1 : exit 0" \
    "image inspect \* : exit 0" \
    "tag myservice1 my.repository/myservice1 : echo tagging image1" \
    "push my.repository/myservice1 : echo pushing myservice1 image" \
    "pull myservice2 : exit 0" \
    "image inspect \* : exit 0" \
    "tag myservice2 my.repository/myservice2:llamas : echo tagging image2" \
    "push my.repository/myservice2:llamas : echo pushing myservice2 image"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice1 : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice1 : echo myservice1" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice1 \* : echo \$4" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice2 : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice2 : echo myservice2" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice2 \* : echo \$4" \

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "tagging image1"
  assert_output --partial "pushing myservice1 image"
  assert_output --partial "tagging image2"
  assert_output --partial "pushing myservice2 image"

  unstub docker-compose
  unstub buildkite-agent
  unstub docker
}

@test "Push a pre-built service with multiple build aliases" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_0=myservice-1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_1=myservice-2
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 config : cat ${PWD}/tests/composefiles/docker-compose.config.v3.2.yml" \
    "-f docker-compose.yml -p buildkite1111 push myservice : echo pushed myservice"

  stub docker \
    "pull \* : echo pulled \$2" \
    "image inspect \* : exit 0" \

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo 'myservice-tag'" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo set image metadata for myservice to \$4" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-1 \* : echo set image metadata for myservice-1 to \$4" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-2 \* : echo set image metadata for myservice-2 to \$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled myservice-tag"
  assert_output --partial "pushed myservice"
  assert_output --partial "set image metadata for myservice"
  assert_output --partial "set image metadata for myservice-1"
  assert_output --partial "set image metadata for myservice-2"

  unstub docker
  unstub docker-compose
  unstub buildkite-agent
}
