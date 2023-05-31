#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'

@test "Project name comes from BUILDKITE_JOB_ID" {
  export BUILDKITE_JOB_ID=11111-1111-11111-11111
  run docker_compose_project_name

  assert_success
  assert_output "buildkite1111111111111111111"
}
