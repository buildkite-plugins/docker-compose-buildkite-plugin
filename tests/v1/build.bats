#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../../lib/shared.bash'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/stdout

teardown() {
  # some test failures may leave this file around
  rm -f docker-compose.buildkite*-override.yml
}

setup_file() {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION=1
}

@test "Build single service" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker-compose
}

@test "Build with no-cache" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --no-cache myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker-compose
}

@test "Build with parallel" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_PARALLEL=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --parallel myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker-compose
}

@test "Build with build args" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_0=MYARG=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_1=MYARG=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --build-arg MYARG=0 --build-arg MYARG=1 myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker-compose
}

@test "Build with a custom config file" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG=tests/composefiles/docker-compose.v2.0.yml

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 build --pull myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker-compose
}

@test "Build with multiple custom config files" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1=tests/composefiles/docker-compose.v2.1.yml

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -f tests/composefiles/docker-compose.v2.1.yml -p buildkite1111 build --pull myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker-compose
}

@test "Build multiple services" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_1=myservice2

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice1 myservice2 : echo built all services"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built all services"

  unstub docker-compose
}

@test "Build with a docker-compose v1.0 configuration file" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v1.0.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v1.0.yml -p buildkite1111 build --pull helloworld : echo built service"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built service"

  unstub docker-compose
}

@test "Build with a cache-from image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"

  unstub docker-compose
}

@test "Build with a cache-from image with no-cache also set" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 build --pull --no-cache helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"
  unstub docker-compose
}

@test "Build with an invalid cache-from tag" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:-latest

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache:-latest"
  assert_output --partial "built helloworld"

  unstub docker-compose
}

@test "Build with a cache-from image with no tag" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache"
  assert_output --partial "built helloworld"

  unstub docker-compose
}

@test "Build with several cache-from images for one service" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:branch-name
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_1=helloworld:my.repository/myservice_cache:latest

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache:branch-name"
  assert_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"

  unstub docker-compose
}

@test "Build with a cache-from image with hyphen" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=hello-world
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=hello-world:my.repository/my-service_cache:latest

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull hello-world : echo built hello-world"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/my-service_cache:latest"
  assert_output --partial "built hello-world"

  unstub docker-compose
}

@test "Build with a service name and cache-from with period" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=hello.world
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=hello.world:my.repository/my-service_cache:latest

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull \* : echo built \$9"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/my-service_cache:latest"
  assert_output --partial "built hello.world"

  unstub docker-compose
}

@test "Build with target" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_TARGET=intermediate

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull \* : echo built \${9}"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "    target: intermediate"

  unstub docker-compose
}

@test "Build with ssh option (but no buildkit)" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SSH=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT=false

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "You can not use the ssh option if you are not using buildkit"
  refute_output --partial "built myservice"
}

@test "Build with ssh option as true and buildkit" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SSH=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --ssh default \* : echo built \${9} with ssh"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "with ssh"

  unstub docker-compose
}

@test "Build with ssh option as string and buildkit" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SSH=context

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --ssh context \* : echo built \${9} with ssh"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "with ssh"

  unstub docker-compose
}

@test "Build with secrets" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SECRETS_0='id=test,file=~/.test'
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SECRETS_1='id=SECRET_VAR'

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --secret \* --secret \* \* : echo built \${11} with secrets \${8} and \${10}"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "with secrets id=test,file=~/.test and id=SECRET_VAR"

  unstub docker-compose
}

@test "Build without pull" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SKIP_PULL=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker-compose
}
