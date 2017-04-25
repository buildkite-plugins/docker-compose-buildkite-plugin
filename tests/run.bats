#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

@test "Get services from an image map" {
  image_map=(
    "myservice1" "myimage1"
    "myservice2" "myimage2"
  )
  run get_services_from_map "${image_map[@]}"

  assert_success
  assert_equal "${#lines[@]}" "2"
  assert_equal "${lines[0]}" "myservice1"
  assert_equal "${lines[1]}" "myservice2"
}

@test "Get prebuilt images from agent metadata" {
  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo service1 image" \
    "meta-data get docker-compose-plugin-built-image-tag-1 : echo service2 image" \
    "meta-data get docker-compose-plugin-built-image-tag-2 : echo "

  run get_prebuilt_images_from_metadata

  assert_success
  assert_output --partial "service1 image"
  assert_output --partial "service2 image"
  unstub buildkite-agent
}

@test "Run without a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 run myservice pwd : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo "

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a single prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run myservice pwd : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo myservice myimage" \
    "meta-data get docker-compose-plugin-built-image-tag-1 : echo "

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with multiple prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice1
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice1 myservice2 : echo pulled services" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run myservice1 pwd : echo ran myservice"

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo myservice1 myimage" \
    "meta-data get docker-compose-plugin-built-image-tag-1 : echo myservice2 myimage " \
    "meta-data get docker-compose-plugin-built-image-tag-2 : echo " \

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}
