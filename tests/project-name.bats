#!/usr/bin/env bats

load '../lib/shared'
load '/usr/local/lib/bats-support/load.bash'
load '/usr/local/lib/bats-assert/load.bash'

@test "Project name comes from BUILDKITE_JOB_ID" {
  export BUILDKITE_JOB_ID=11111-1111-11111-11111
  run docker_compose_project_name

  assert_success
  assert_output "buildkite1111111111111111111"
}
