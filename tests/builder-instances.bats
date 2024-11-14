#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'

@test "No Builder Instance Parameters" {

    stub docker \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output "~~~ :docker: Using Default Builder 'test' with Driver 'driver'"
}

@test "Create Builder Instance with invalid Name" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true

    run "$PWD"/hooks/pre-command

    assert_failure
    assert_output "+++ 🚨 Builder Name cannot be empty when using 'create' or 'use' parameters"
}

@test "Use Builder Instance with invalid Name" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true

    run "$PWD"/hooks/pre-command

    assert_failure
    assert_output "+++ 🚨 Builder Name cannot be empty when using 'create' or 'use' parameters"
}

@test "Create Builder Instance with invalid Driver" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=""

    run "$PWD"/hooks/pre-command

    assert_failure
    assert_output --partial "+++ 🚨 Invalid driver: ''"
    assert_output --partial "Valid Drivers: docker-container, kubernetes, remote"
}
