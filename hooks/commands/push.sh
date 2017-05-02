#!/bin/bash
set -ueo pipefail

# First we need to pull down any prebuilt images and tag them as the
# correct thing for pushing
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
built_images=( $(get_prebuilt_images_from_metadata) )
built_services=()

echo "~~~ :docker: Found $((${#built_images[@]}/2)) pre-built services" >&2;

if [[ ${#built_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config for pre-built images" >&2;
  build_image_override_file "${built_images[@]}" | tee "$override_file"
  built_services=( $(get_services_from_map "${built_images[@]}") )

  echo "~~~ :docker: Pulling pre-built services ${built_services[*]}" >&2;
  run_docker_compose -f "$override_file" pull "${built_services[@]}"
fi

push_images=()
push_services=()

# Then we figure out what to push, and where
for line in $(plugin_read_list PUSH) ; do
  IFS=':' read -a tokens <<< "$line"
  service=${tokens[0]}
  push_services+=(${tokens[0]})

  # two or three tokens is a service:image(:tag) combo
  if [[ ${#tokens[@]} -gt 1 ]] ; then
     image="$(IFS=:; echo "${tokens[*]:1}")"
     prebuilt_image=

    # if the service is prebuilt, tag the prebuilt image to match
    if prebuilt_image=$(get_prebuilt_image "$service" "${built_images[@]}") ; then
      docker tag "$prebuilt_image" "$image"
    fi

    push_images+=("$service" "$(IFS=:; echo "${tokens[*]:1}")")
  fi
done

if [[ ${#push_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config for pushing" >&2;
  build_image_override_file "${push_images[@]}" | tee "$override_file"
fi

echo "~~~ :docker: Pushing services ${push_services[*]}"

if [[ -f "$override_file" ]]; then
  run_docker_compose -f "$override_file" push "${push_services[@]}"
else
  run_docker_compose push "${push_services[@]}"
fi
