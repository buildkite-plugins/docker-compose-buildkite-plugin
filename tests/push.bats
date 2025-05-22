#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared.bash'

# export DOCKER_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

setup_file() {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
}

@test "Push a single service with an image in its config" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=app

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-app \* : echo tagged \$4"

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : cat $PWD/tests/composefiles/docker-compose.config.v3.2.yml" \
    "image inspect somewhere.dkr.ecr.some-region.amazonaws.com/blah : exit 0" \
    "compose -f docker-compose.yml -p buildkite1111 push app : echo pushed app"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pushed app"

  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo ''" \
    "pull myimage : echo pulled prebuilt image" \
    "image inspect myimage : exit 0" \
    "tag myimage my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo tagged \$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"

  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag in compatibility mode" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMPATIBILITY=true

  stub docker \
    "compose --compatibility -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull myimage : echo pulled prebuilt image" \
    "image inspect \* : echo found \$3" \
    "tag myimage my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo tagged \$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"

  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with an invalid tag" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:-llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull myimage : echo pulled prebuilt image" \
    "image inspect \* : echo found \$3" \
    "tag myimage my.repository/myservice:-llamas : exit 1"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Pulling pre-built service"
  refute_output --partial "tagged image"

  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag containing a variable and the expand option on" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH="myservice:my.repository/myservice:\$MY_VAR"
  export MY_VAR="llamas"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_EXPAND_PUSH_VARS=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo ''" \
    "pull myimage : echo pulled prebuilt image" \
    "image inspect myimage : exit 0" \
    "tag myimage my.repository/myservice:llamas : echo tagged image" \
    "push my.repository/myservice:llamas : echo pushed myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo tagged \$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled prebuilt image"
  assert_output --partial "tagged image"
  assert_output --partial "pushed myservice"

  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image with a repository and a tag containing a variable and the expand option off" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH="myservice:my.repository/myservice:\$MY_VAR"
  export MY_VAR="llamas"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_EXPAND_PUSH_VARS=false

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull myimage : echo pulled prebuilt image" \
    "image inspect \* : echo found \$3" \
    'tag myimage my.repository/myservice:\$MY_VAR : exit 1'

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Pulling pre-built service"
  refute_output --partial "tagged image"

  unstub docker
  unstub buildkite-agent
}

@test "Push a prebuilt image to multiple tags" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice:my.repository/myservice:llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice:my.repository/myservice:latest
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_2=myservice:my.repository/myservice:alpacas

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "pull prebuilt : echo pulled prebuilt image" \
    "image inspect prebuilt : exit 0" \
    "tag prebuilt my.repository/myservice:llamas : echo tagged image1" \
    "push my.repository/myservice:llamas : echo pushed myservice1" \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "image inspect prebuilt2 : exit 0" \
    "tag prebuilt2 my.repository/myservice:latest : echo tagged image2" \
    "push my.repository/myservice:latest : echo pushed myservice2" \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah" \
    "image inspect prebuilt3 : exit 0" \
    "tag prebuilt3 my.repository/myservice:alpacas : echo tagged image3" \
    "push my.repository/myservice:alpacas : echo pushed myservice3"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo tagged \$4" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt2" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo tagged \$4" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo prebuilt3" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo tagged \$4"

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

@test "Push a single service without prebuilt nor service image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=helper:my.repository/helper:llamas

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-helper : exit 1"

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : cat $PWD/tests/composefiles/docker-compose.config.v3.2.yml"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial 'No prebuilt-image nor built image found for service to push'

  unstub docker
  unstub buildkite-agent
}

@test "Push two services with pre-built images" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice1:my.repository/myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice2:my.repository/myservice2:llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah " \
    "pull prebuilt1 : exit 0" \
    "image inspect \* : echo found image \$3" \
    "tag prebuilt1 my.repository/myservice1 : echo tagging image1" \
    "push my.repository/myservice1 : echo pushing myservice1 image" \
    "compose -f docker-compose.yml -p buildkite1111 config : echo blah " \
    "pull prebuilt2 : exit 0" \
    "image inspect \* : echo found image \$3" \
    "tag prebuilt2 my.repository/myservice2:llamas : echo tagging image2" \
    "push my.repository/myservice2:llamas : echo pushing myservice2 image"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice1 : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice1 : echo prebuilt1" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice1 \* : echo tagged \$4" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice2 : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice2 : echo prebuilt2" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice2 \* : echo tagged \$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "tagging image1"
  assert_output --partial "pushing myservice1 image"
  assert_output --partial "tagging image2"
  assert_output --partial "pushing myservice2 image"

  unstub docker
  unstub buildkite-agent
}

@test "Push pre-built image with aliases" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_0=myservice-1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_1=myservice-2

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : echo ''" \
    "pull myservice-tag : exit 0" \
    "image inspect \* : exit 0" \
    "compose -f docker-compose.yml -p buildkite1111 push myservice : echo pushed myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myservice-tag" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice \* : echo \$4" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-1 \* : echo myservice-1:\$4" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-2 \* : echo myservice-2:\$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Using pre-built image myservice-tag"
  assert_output --partial "myservice-1:myservice-tag"
  assert_output --partial "myservice-2:myservice-tag"

  unstub docker
  unstub buildkite-agent
}

@test "Push service with image with aliases" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=app
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_0=myservice-1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_1=myservice-2

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 config : cat ${PWD}/tests/composefiles/docker-compose.config.v3.2.yml" \
    "image inspect \* : exit 0" \
    "compose -f docker-compose.yml -p buildkite1111 push app : echo pushed myservice"

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-app \* : echo \$4" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-1 \* : echo myservice-1:\$4" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-2 \* : echo myservice-2:\$4"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Service has an image configuration: somewhere.dkr.ecr.some-region.amazonaws.com/blah"
  assert_output --partial "myservice-1:somewhere.dkr.ecr.some-region.amazonaws.com/blah"
  assert_output --partial "myservice-2:somewhere.dkr.ecr.some-region.amazonaws.com/blah"

  unstub docker
  unstub buildkite-agent
}
