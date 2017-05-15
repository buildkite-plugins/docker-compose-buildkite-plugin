
#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'
load '../lib/shared'
load '../lib/metadata'

@test "Get prebuilt images from agent metadata (two images)" {
  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 2" \
    "meta-data get docker-compose-plugin-built-image-tag-0 : echo service1" \
    "meta-data get docker-compose-plugin-built-image-tag-service1 : echo image" \
    "meta-data get docker-compose-plugin-built-image-tag-1 : echo service2" \
    "meta-data get docker-compose-plugin-built-image-tag-service2 : echo image "

  run get_prebuilt_images_from_metadata

  assert_success
  assert_output --partial "service1 image"
  assert_output --partial "service2 image"
  unstub buildkite-agent
}

@test "Get prebuilt images from agent metadata (no images)" {
  stub buildkite-agent \
    "meta-data get docker-compose-plugin-built-image-count : echo 0"

  run get_prebuilt_images_from_metadata

  assert_success
  unstub buildkite-agent
}

@test "Get services from an image map" {
  image_map=(
    "myservice1" "myimage1"
    "myservice2" "myimage2"
  )
  run get_services_from_map "${image_map[@]}"

  assert_success
  assert_equal "${#lines[@]}" "2"
  assert_equal "${lines[0]}" "myservice1"
  assert_equal "${lines[1]}" "myservice2"
}


@test "Get prebuilt image for service from an image map" {
  image_map=(
    "myservice1" "myimage1"
    "myservice2" "myimage2"
  )

  run get_prebuilt_image "myservice1" "${image_map[@]}"
  assert_success
  assert_output "myimage1"

  refute get_prebuilt_image "missingservice" "${image_map[@]}"
}
