#!/usr/bin/env bats

load '../lib/shared'
load '../lib/run'

@test "Get prebuilt image from agent metadata" {
  export HIDE_PROMPT=1
  buildkite-agent() {
    echo "$@"
  }
  run get_prebuilt_image_from_metadata "llama"
  echo $output
  [ "$status" -eq 0 ]
  [ "$output" = "meta-data get docker-compose-plugin-built-image-tag-llama" ]
}