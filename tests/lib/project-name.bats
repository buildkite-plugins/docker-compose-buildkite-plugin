#!/usr/bin/env bats

load '../../lib/shared'

@test "Project name comes from BUILDKITE_JOB_ID" {
  export BUILDKITE_JOB_ID=11111-1111-11111-11111
  run docker_compose_project_name
  [ "$status" -eq 0 ]
  [ "$output" == "buildkite1111111111111111111" ]
}
