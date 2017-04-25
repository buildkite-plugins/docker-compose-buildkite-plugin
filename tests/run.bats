#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/run'

@test "Get prebuilt image from agent metadata" {
  export HIDE_PROMPT=1

  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-tag-llama : echo blah"

  run get_prebuilt_image_from_metadata "llama"

  assert_success
  assert_output "blah"
}