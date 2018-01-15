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

myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_from:
        - my.repository/myservice:latest
EOF
)

@test "Build an docker-compose override file" {
  run build_image_override_file_with_version "2.1" "myservice" "newimage:1.0.0" ""

  assert_success
  assert_output "$myservice_override_file1"
}

@test "Build an docker-compose override file with multiple entries" {
  run build_image_override_file_with_version "2.1" \
    "myservice1" "newimage1:1.0.0" "" \
    "myservice2" "newimage2:1.0.0" ""

  assert_success
  assert_output "$myservice_override_file2"
}

@test "Build a docker-compose file with cache-from" {
  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with cache-from and compose-file version 2" {
  run build_image_override_file_with_version "2" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 2.0" {
  run build_image_override_file_with_version "2.0" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 2.1" {
  run build_image_override_file_with_version "2.1" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 3" {
  run build_image_override_file_with_version "3" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 3.0" {
  run build_image_override_file_with_version "3.0" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 3.1" {
  run build_image_override_file_with_version "3.1" "myservice" "newimage:1.0.0" "my.repository/myservice:latest"

  assert_failure
}
