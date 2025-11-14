#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'

# export DOCKER_STUB_DEBUG=/dev/tty

@test "No Builder Instance Parameters" {

    stub docker \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output "~~~ :docker: Using Default Builder 'test' with Driver 'driver'"

    unstub docker
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

@test "Create Builder Instance with valid Driver" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'docker-container'"
    assert_output --partial "~~~ :docker: Using Default Builder 'test' with Driver 'driver'"

    unstub docker
}

@test "Create Builder Instance with valid Driver but already Exists" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container

    stub docker \
        "buildx inspect builder-name : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Not Creating Builder Instance 'builder-name' as already exists"
    assert_output --partial "~~~ :docker: Using Default Builder 'test' with Driver 'driver'"

    unstub docker
}

@test "Create Builder Instance with valid Driver but not used" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=false
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'docker-container'"
    assert_output --partial "~~~ :warning: Builder Instance 'builder-name' created but will not be used as 'use: true' parameter not specified"

    assert_output --partial "~~~ :docker: Using Default Builder 'test' with Driver 'driver'"

    unstub docker
}

@test "Use Builder Instance that does not Exist" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name

    stub docker \
        "buildx inspect builder-name : exit 1"

    run "$PWD"/hooks/pre-command

    assert_failure
    assert_output "+++ 🚨 Builder Instance 'builder-name' does not exist"

    unstub docker
}

@test "Use Builder Instance that Exists" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name

    stub docker \
        "buildx inspect builder-name : exit 0"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output "~~~ :docker: Using Builder Instance '$BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME'"

    unstub docker
}

@test "Remove Builder Instance that Exists" {
    export BUILDKITE_BUILD_NUMBER=111
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_REMOVE=true

    stub docker \
        "buildx inspect builder-name : exit 0" \
        "buildx stop builder-name : exit 0" \
        "buildx rm builder-name : exit 0"

    run "$PWD"/hooks/pre-exit

    assert_success
    assert_output "~~~ :docker: Cleaning up Builder Instance 'builder-name'"

    unstub docker
}

@test "Remove Builder Instance that Exists with keep-daemon" {
    export BUILDKITE_BUILD_NUMBER=111
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_REMOVE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_KEEP_DAEMON=true

    stub docker \
        "buildx inspect builder-name : exit 0" \
        "buildx stop builder-name : exit 0" \
        "buildx rm builder-name --keep-daemon : exit 0"

    run "$PWD"/hooks/pre-exit

    assert_success
    assert_output "~~~ :docker: Cleaning up Builder Instance 'builder-name'"

    unstub docker
}

@test "Remove Builder Instance that Exists with keep-daemon and keep-state" {
    export BUILDKITE_BUILD_NUMBER=111
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_REMOVE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_KEEP_DAEMON=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_KEEP_STATE=true

    stub docker \
        "buildx inspect builder-name : exit 0" \
        "buildx stop builder-name : exit 0" \
        "buildx rm builder-name --keep-daemon --keep-state : exit 0"

    run "$PWD"/hooks/pre-exit

    assert_success
    assert_output "~~~ :docker: Cleaning up Builder Instance 'builder-name'"

    unstub docker
}

@test "Remove Builder Instance that does not Exists" {
    export BUILDKITE_BUILD_NUMBER=111
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_REMOVE=true

    stub docker \
        "buildx inspect builder-name : exit 1"

    run "$PWD"/hooks/pre-exit

    assert_success
    assert_output "~~~ :warning: Cannot remove Builder Instance 'builder-name' as does not exist"

    unstub docker
}

@test "Create Builder Instance with retry on failure" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE_RETRIES=3

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'docker-container'"
    assert_output --partial "Exited with 1"
    assert_output --partial "Retrying"
    assert_output --partial "~~~ :docker: Using Default Builder 'test' with Driver 'driver'"

    unstub docker
}

@test "Create Builder Instance with retry exhausted" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE_RETRIES=2

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 1"

    run "$PWD"/hooks/pre-command

    assert_failure
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'docker-container'"
    assert_output --partial "Exited with 1"
    assert_output --partial "Failed 2 retries"

    unstub docker
}

@test "Create Builder Instance with default retry count" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'docker-container'"
    assert_output --partial "Retrying"

    unstub docker
}

@test "push-on-build with docker-container driver succeeds" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=docker-container
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver docker-container --bootstrap : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'docker-container'"

    unstub docker
}

@test "push-on-build with remote driver succeeds" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_CREATE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_DRIVER=remote
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_REMOTE_ADDRESS=tcp://localhost:1234
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true

    stub docker \
        "buildx inspect builder-name : exit 1" \
        "buildx create --name builder-name --driver remote --bootstrap tcp://localhost:1234 : exit 0" \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: driver'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Creating Builder Instance 'builder-name' with Driver 'remote'"

    unstub docker
}

@test "push-on-build with docker driver fails" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true

    stub docker \
        "buildx inspect : echo 'Name: test'" \
        "buildx inspect : echo 'Driver: docker'"

    run "$PWD"/hooks/pre-command

    assert_failure
    assert_output --partial "+++ 🚨 push-on-build requires builder driver to be 'remote' or 'docker-container'"
    assert_output --partial "Current driver: 'docker'"

    unstub docker
}

@test "push-on-build with used builder checks driver" {
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_USE=true
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_NAME=builder-name
    export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILDER_PUSH_ON_BUILD=true

    stub docker \
        "buildx inspect builder-name : exit 0" \
        "buildx inspect builder-name : echo 'Driver: docker-container'"

    run "$PWD"/hooks/pre-command

    assert_success
    assert_output --partial "~~~ :docker: Using Builder Instance 'builder-name'"

    unstub docker
}
