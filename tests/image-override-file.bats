#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

myservice_override_file=$(cat <<-EOF
version: '2.1'
services:
  myservice:
    image: newimage:1.0.0
EOF
)

@test "Build an docker-compose override file" {
  run build_image_override_file_with_version "2.1" "myservice" "newimage:1.0.0"

  assert_success
  assert_output "$myservice_override_file"
}
