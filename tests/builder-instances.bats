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
