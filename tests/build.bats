#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/stdout
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/stdout
# export BATS_MOCK_TMPDIR=$PWD

@test "Build without a repository" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice"

  run $PWD/hooks/command

  unstub docker-compose
  assert_success
  assert_output --partial "built myservice"
}

@test "Build with no-cache" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull --no-cache myservice : echo built myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker-compose
}

@test "Build with build args" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_0=MYARG=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_1=MYARG=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull --build-arg MYARG=0 --build-arg MYARG=1 myservice : echo built myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  unstub docker-compose
}

@test "Build with a repository" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/llamas:test-myservice-build-1 : echo set image metadata for myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "pushed myservice"
  assert_output --partial "set image metadata for myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Build with a repository and custom config file" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml my.repository/llamas:test-myservice-build-1 : echo set image metadata for myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "pushed myservice"
  assert_output --partial "set image metadata for myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Build with a repository and multiple custom config files" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1=tests/composefiles/docker-compose.v2.1.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -f tests/composefiles/docker-compose.v2.1.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
    "-f tests/composefiles/docker-compose.v2.0.yml -f tests/composefiles/docker-compose.v2.1.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml-tests/composefiles/docker-compose.v2.1.yml my.repository/llamas:test-myservice-build-1 : echo set image metadata for myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "pushed myservice"
  assert_output --partial "set image metadata for myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Build with a repository and multiple services" {
  export BUILDKITE_JOB_ID=1112
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_1=myservice2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1112 -f docker-compose.buildkite-1-override.yml build --pull myservice1 myservice2 : echo built all services" \
    "-f docker-compose.yml -p buildkite1112 -f docker-compose.buildkite-1-override.yml push myservice1 myservice2 : echo pushed all services" \

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice1 my.repository/llamas:test-myservice1-build-1 : echo set image metadata for myservice1" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice2 my.repository/llamas:test-myservice2-build-1 : echo set image metadata for myservice2"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built all services"
  assert_output --partial "pushed all services"
  assert_output --partial "set image metadata for myservice1"
  assert_output --partial "set image metadata for myservice2"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Build with a docker-compose v1.0 configuration file" {
  export BUILDKITE_JOB_ID=1112
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v1.0.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "Compose file versions 2.0 and above"
}

@test "Build with a cache-from image" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "pull my.repository/myservice_cache:latest : echo pulled cache image"

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled cache image"
  assert_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"
  unstub docker
  unstub docker-compose
}

@test "Build with a cache-from image when pulling of the cache-from image failed" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "pull my.repository/myservice_cache:latest : exit 1"

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "my.repository/myservice_cache:latest will not be used as a cache for helloworld"
  refute_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"
  unstub docker
  unstub docker-compose
}

@test "Build with a cache-from image with hyphen" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=hello-world
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=hello-world:my.repository/my-service_cache:latest
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker \
    "pull my.repository/my-service_cache:latest : echo pulled cache image"

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull hello-world : echo built hello-world"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled cache image"
  assert_output --partial "- my.repository/my-service_cache:latest"
  assert_output --partial "built hello-world"
  unstub docker
  unstub docker-compose
}

@test "Build with a cache-from image retry on failing pull" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG="tests/composefiles/docker-compose.v3.2.yml"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=helloworld
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CACHE_FROM_0=helloworld:my.repository/myservice_cache:latest
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_RETRIES=3

  stub docker \
    "pull my.repository/myservice_cache:latest : exit 1" \
    "pull my.repository/myservice_cache:latest : exit 1" \
    "pull my.repository/myservice_cache:latest : echo pulled cache image"

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v3.2.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull helloworld : echo built helloworld"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled cache image"
  assert_output --partial "- my.repository/myservice_cache:latest"
  assert_output --partial "built helloworld"
  unstub docker
  unstub docker-compose
}

@test "Build with a custom image-name" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_NAME=my-llamas-image
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml push myservice : echo pushed myservice" \

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice my.repository/llamas:my-llamas-image : echo set image metadata for myservice"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "pushed myservice"
  assert_output --partial "set image metadata for myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Build multiple images with custom image-names" {
  export BUILDKITE_JOB_ID=1112
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_0=myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_1=myservice2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_NAME_0=my-llamas-image-1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_NAME_1=my-llamas-image-2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY=my.repository/llamas
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1112 -f docker-compose.buildkite-1-override.yml build --pull myservice1 myservice2 : echo built all services" \
    "-f docker-compose.yml -p buildkite1112 -f docker-compose.buildkite-1-override.yml push myservice1 myservice2 : echo pushed all services" \

  stub buildkite-agent \
    "meta-data set docker-compose-plugin-built-image-tag-myservice1 my.repository/llamas:my-llamas-image-1 : echo set image metadata for myservice1" \
    "meta-data set docker-compose-plugin-built-image-tag-myservice2 my.repository/llamas:my-llamas-image-2 : echo set image metadata for myservice2"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "built all services"
  assert_output --partial "pushed all services"
  assert_output --partial "set image metadata for myservice1"
  assert_output --partial "set image metadata for myservice2"
  unstub docker-compose
  unstub buildkite-agent
}


