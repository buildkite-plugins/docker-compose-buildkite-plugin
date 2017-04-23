#!/usr/bin/env bats

load '../../lib/shared'

myservice_override_file=$(cat <<-EOF
version: '2'
services:
  myservice:
    image: newimage:1.0.0
EOF
)

@test "Build an docker-compose override file" {
  run build_image_override_file "myservice" "newimage:1.0.0"
  echo
  [ "$status" -eq 0 ]
  [ "$output" == "$myservice_override_file" ]
}
