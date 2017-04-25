#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'

myservice_override_file1=$(cat <<-EOF
version: '2.1'
services:
  myservice:
    image: newimage:1.0.0
EOF
)

myservice_override_file2=$(cat <<-EOF
version: '2.1'
services:
  myservice1:
    image: newimage1:1.0.0
  myservice2:
    image: newimage2:1.0.0
EOF
)

@test "Build an docker-compose override file" {
  run build_image_override_file_with_version "2.1" "myservice" "newimage:1.0.0"

  assert_success
  assert_output "$myservice_override_file1"
}

@test "Build an docker-compose override file with multiple entries" {
  run build_image_override_file_with_version "2.1" \
    "myservice1" "newimage1:1.0.0" \
    "myservice2" "newimage2:1.0.0"

  assert_success
  assert_output "$myservice_override_file2"
}
