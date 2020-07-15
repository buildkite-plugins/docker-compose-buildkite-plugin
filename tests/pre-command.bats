#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

@test "Pre-command sets Buildkit to use plain output" {
  BUILDKIT_PROGRESS=

  source "$PWD/hooks/pre-command"

  assert_equal "plain" "${BUILDKIT_PROGRESS}"

  unset BUILDKIT_PROGRESS
}
