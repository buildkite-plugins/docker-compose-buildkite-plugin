#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'

@test "Build a docker-compose override file" {
  myservice_override_file1=$(cat <<-EOF
version: '2.1'
services:
  myservice:
    image: newimage:1.0.0
EOF
  )
  run build_image_override_file_with_version "2.1" "myservice" "newimage:1.0.0" "" 0

  assert_success
  assert_output "$myservice_override_file1"
}

@test "Build a docker-compose override file with multiple entries" {
  myservice_override_file2=$(cat <<-EOF
version: '2.1'
services:
  myservice1:
    image: newimage1:1.0.0
  myservice2:
    image: newimage2:1.0.0
EOF
  )

  run build_image_override_file_with_version "2.1" \
    "myservice1" "newimage1:1.0.0" "" 0 0 0 \
    "myservice2" "newimage2:1.0.0" "" 0 0 0

  assert_success
  assert_output "$myservice_override_file2"
}

@test "Build a docker-compose file with target" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      target: build
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "build" 0

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with cache-from" {
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

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple cache-from entries" {
  myservice_override_file4=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_from:
        - my.repository/myservice:latest
        - my.repository/myservice:target
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 2 "my.repository/myservice:latest" "my.repository/myservice:target"

  assert_success
  assert_output "$myservice_override_file4"
}

@test "Build a docker-compose file with labels" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      labels:
        - com.buildkite.test=test
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 0 0 1 "com.buildkite.test=test"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple labels" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      labels:
        - com.buildkite.test=test
        - com.buildkite.test2=test2
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 0 0 2 "com.buildkite.test=test" "com.buildkite.test2=test2"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple cache-from and multiple labels" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_from:
        - my.repository/myservice:latest
        - my.repository/myservice:target
      labels:
        - com.buildkite.test=test
        - com.buildkite.test2=test2
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 2 "my.repository/myservice:latest" "my.repository/myservice:target" 0 2 "com.buildkite.test=test" "com.buildkite.test2=test2"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple cache-from and multiple labels and target" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      target: build
      cache_from:
        - my.repository/myservice:latest
        - my.repository/myservice:target
      labels:
        - com.buildkite.test=test
        - com.buildkite.test2=test2
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "build" 2 "my.repository/myservice:latest" "my.repository/myservice:target" 0 2 "com.buildkite.test=test" "com.buildkite.test2=test2"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with cache-from and compose-file version 2" {
  run build_image_override_file_with_version "2" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 2.0" {
  run build_image_override_file_with_version "2.0" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 2.1" {
  run build_image_override_file_with_version "2.1" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 3" {
  run build_image_override_file_with_version "3" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 3.0" {
  run build_image_override_file_with_version "3.0" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-from and compose-file version 3.1" {
  run build_image_override_file_with_version "3.1" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest"

  assert_failure
}

@test "Build a docker-compose file with cache-to" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_to:
        - user/app:cache
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 0 1 "user/app:cache"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple cache-to entries" {
  myservice_override_file4=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_to:
        - user/app:cache
        - type=local,dest=path/to/cache
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 0 2 "user/app:cache" "type=local,dest=path/to/cache"

  assert_success
  assert_output "$myservice_override_file4"
}


@test "Build a docker-compose file with cache-from and cache-to" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      cache_from:
        - my.repository/myservice:latest
      cache_to:
        - user/app:cache
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "" 1 "my.repository/myservice:latest" 1 "user/app:cache"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple cache-from, multiple cache-to and multiple labels and target" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice:
    image: newimage:1.0.0
    build:
      target: build
      cache_from:
        - my.repository/myservice:latest
        - my.repository/myservice:target
      cache_to:
        - user/app:cache
        - type=local,dest=path/to/cache
      labels:
        - com.buildkite.test=test
        - com.buildkite.test2=test2
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice" "newimage:1.0.0" "build" 2 "my.repository/myservice:latest" "my.repository/myservice:target" 2 "user/app:cache" "type=local,dest=path/to/cache" 2 "com.buildkite.test=test" "com.buildkite.test2=test2"

  assert_success
  assert_output "$myservice_override_file3"
}

@test "Build a docker-compose file with multiple services, multiple cache-from, multiple cache-to and multiple labels and target" {
  myservice_override_file3=$(cat <<-EOF
version: '3.2'
services:
  myservice-1:
    image: newimage:1.0.0
    build:
      target: build
      cache_from:
        - my.repository/myservice-1:latest
        - my.repository/myservice-1:target
      cache_to:
        - user/app:cache
        - type=local,dest=path/to/cache
      labels:
        - com.buildkite.test=test
        - com.buildkite.test2=test2
  myservice-2:
    image: newimage:2.0.0
    build:
      target: build-2
      cache_from:
        - my.repository/myservice-2:latest
        - my.repository/myservice-2:target
      cache_to:
        - user/app:cache
        - type=local,dest=path/to/cache-2
      labels:
        - com.buildkite.test3=test3
        - com.buildkite.test4=test4
EOF
  )

  run build_image_override_file_with_version "3.2" "myservice-1" "newimage:1.0.0" "build" 2 "my.repository/myservice-1:latest" "my.repository/myservice-1:target" 2 "user/app:cache" "type=local,dest=path/to/cache" 2 "com.buildkite.test=test" "com.buildkite.test2=test2" "myservice-2" "newimage:2.0.0" "build-2" 2 "my.repository/myservice-2:latest" "my.repository/myservice-2:target" 2 "user/app:cache" "type=local,dest=path/to/cache-2" 2 "com.buildkite.test3=test3" "com.buildkite.test4=test4"

  assert_success
  assert_output "$myservice_override_file3"
}
