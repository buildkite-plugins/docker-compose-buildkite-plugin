#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/stdout
# export BATS_MOCK_TMPDIR=$PWD

teardown() {
  # some test failures may leave this file around
  rm -f docker-compose.buildkite*-override.yml
}

setup_file() {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
}

@test "Build without a repository" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with builder" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=mybuilder
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --builder mybuilder myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with no-cache" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --no-cache myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with parallel" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_PARALLEL=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --parallel myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with build args" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_0=MYARG=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_1=MYARG=1

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --build-arg MYARG=0 --build-arg MYARG=1 myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with a repository and multiple build aliases" {
  skip 'move to push'
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_0=myservice-1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ALIAS_1=myservice-2

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with an override file and docker-compose v1.0 configuration file" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v1.0.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "versions 2.0 and above"
  refute_output --partial "built service"
}

@test "Build with a cache-from image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"

  unstub docker
}

@test "Build with a cache-from image with no-cache also set" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 build --pull --no-cache helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"

  unstub docker
}

@test "Build with an invalid cache-from tag" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:-latest

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "pulled cache image"
  assert_output --partial "- my.repository/myservice_cache:-latest"
  assert_output --partial "built helloworld"

  unstub docker
}

@test "Build with a cache-from image with no tag" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache"
  assert_output --partial "built helloworld"

  unstub docker
}

@test "Build with several cache-from images for one service" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:branch-name
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_1=helloworld:my.repository/myservice_cache:latest

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/myservice_cache:branch-name"
  assert_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"

  unstub docker
}

@test "Build with a cache-from image with hyphen" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=hello-world
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=hello-world:my.repository/my-service_cache:latest

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull hello-world : echo built hello-world"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/my-service_cache:latest"
  assert_output --partial "built hello-world"

  unstub docker
}

@test "Build with a service name and cache-from with period" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=hello.world
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=hello.world:my.repository/my-service_cache:latest

  stub docker \
    "compose -f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull \* : echo built \${10}}"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "- my.repository/my-service_cache:latest"
  assert_output --partial "built hello.world"

  unstub docker
}

@test "Build with target" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_TARGET=intermediate

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull \* : echo built \${10}"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "    target: intermediate"

  unstub docker
}

@test "Build with ssh option (but no buildkit)" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SSH=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT=false

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --ssh default \* : echo built \${10} with ssh"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "with ssh"

  unstub docker
}

@test "Build with ssh option as true and buildkit" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SSH=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --ssh default \* : echo built \${10} with ssh"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "with ssh"

  unstub docker
}

@test "Build with ssh option as string and buildkit" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SSH=context

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --ssh context \* : echo built \${10} with ssh"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "with ssh"

  unstub docker
}

@test "Build without pull" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SKIP_PULL=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with buildkit-inline-cache" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_0=MYARG=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_1=MYARG=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDKIT_INLINE_CACHE=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --build-arg BUILDKIT_INLINE_CACHE=1 --build-arg MYARG=0 --build-arg MYARG=1 myservice : echo built myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker
}

@test "Build with with-dependencies" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WITH_DEPENDENCIES=true

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 build --pull --with-dependencies myservice : echo built myservice"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"

  unstub docker
}

@test "Build with push-on-build and push targets" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull --push myservice : echo built and pushed myservice"

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/myservice:llamas : echo set metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built and pushed myservice"
  assert_output --partial "Setting prebuilt image metadata for myservice: my.repository/myservice:llamas"

  unstub docker
  unstub buildkite-agent
}

@test "Build with push-on-build fails when service not in build list" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=otherservice:my.repository/otherservice:llamas

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "+++ 🚨 Service 'otherservice' specified in push but not in build. With push-on-build, all pushed services must be built."
}

@test "Build with push-on-build auto-converts cache-from" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=myservice:my.registry/cache:latest
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH=myservice:my.repository/myservice:llamas

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull --push myservice : echo built and pushed myservice"

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/myservice:llamas : echo set metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Converting cache-from registry references to type=registry format for multi-arch build"
  assert_output --partial "built and pushed myservice"

  unstub docker
  unstub buildkite-agent
}

@test "Build with push-on-build and multiple tags" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice:my.repository/myservice:llamas
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice:my.repository/myservice:latest

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull --push myservice : echo built and pushed myservice" \
    "buildx imagetools create --tag my.repository/myservice:latest my.repository/myservice:llamas : echo tagged additional image"

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/myservice:llamas : echo set metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built and pushed myservice"
  assert_output --partial "Setting prebuilt image metadata for myservice: my.repository/myservice:llamas"
  assert_output --partial "Tagging and pushing additional images for myservice"
  assert_output --partial "Pushing additional tag: my.repository/myservice:latest"

  unstub docker
  unstub buildkite-agent
}

@test "Build with push-on-build and three tags" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_0=myservice:my.repository/myservice:commit-abc123
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_1=myservice:my.repository/myservice:branch-main
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_2=myservice:my.repository/myservice:latest

  stub docker \
    "compose -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull --push myservice : echo built and pushed myservice" \
    "buildx imagetools create --tag my.repository/myservice:branch-main my.repository/myservice:commit-abc123 : echo tagged second image" \
    "buildx imagetools create --tag my.repository/myservice:latest my.repository/myservice:commit-abc123 : echo tagged third image"

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/myservice:commit-abc123 : echo set metadata"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built and pushed myservice"
  assert_output --partial "Setting prebuilt image metadata for myservice: my.repository/myservice:commit-abc123"
  assert_output --partial "Tagging and pushing additional images for myservice"
  assert_output --partial "Pushing additional tag: my.repository/myservice:branch-main"
  assert_output --partial "Pushing additional tag: my.repository/myservice:latest"

  unstub docker
  unstub buildkite-agent
}
