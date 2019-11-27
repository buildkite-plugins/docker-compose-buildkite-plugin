#!/bin/bash
set -ueo pipefail

image_repository="$(plugin_read_config IMAGE_REPOSITORY)"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"
push_retries="$(plugin_read_config PUSH_RETRIES "0")"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()

service_name_cache_from_var() {
  local service_name="$1"
  echo "cache_from__${service_name//-/_}"
}

if [[ -z "$image_repository" ]] ; then
  echo "+++ ⚠️ Build step missing image-repository setting"
  echo "This build step has no image-repository set. Without an image-repository, the Docker image won't be pushed to a repository, and won't be automatically used by any run steps."
fi

build_services=$(plugin_read_list BUILD)

# Read any cache-from parameters provided and pull down those images first
for line in $(plugin_read_list CACHE_FROM) ; do
  IFS=':' read -r -a tokens <<< "$line"
  service_name=${tokens[0]}
  service_image=$(IFS=':'; echo "${tokens[*]:1}")
  cache_image_name="$(service_name_cache_from_var "$service_name")"

  if [[ -n ${!cache_image_name+x} ]]; then
    continue # skipping since there's already a pulled cache image for this service
  fi

  # check the the cache-from line will be useful (that is, refers to a service that is being built
  # by this step)
  if ! in_array "$service_name" "${build_services[@]}"; then
    echo "+++ ⚠ cache-from refers to service '$service_name' that is not being built"
    echo "Found cache-from specification that has no effect:"
    echo "    $line"
    echo "Service name '$service_name' is not one of the services being built:"
    echo "    ${build_services[*]}"
  fi

  echo "~~~ :docker: Pulling cache image for $service_name"
  if retry "$pull_retries" plugin_prompt_and_run docker pull "$service_image" ; then
    printf -v "$cache_image_name" "%s" "$service_image"
  else
    echo "!!! :docker: Pull failed. $service_image will not be used as a cache for $service_name"
  fi
done

# Run through all images in the build property, either a single item or a list
# and build up a list of service name, image name and optional cache-froms to
# write into a docker-compose override file
service_idx=0
for service_name in "${build_services[@]}" ; do
  image_name=$(build_image_name "${service_name}" "${service_idx}")
  service_idx=$((service_idx+1))

  if [[ -n "$image_repository" ]] ; then
    image_name="${image_repository}:${image_name}"
  fi

  build_images+=("$service_name" "$image_name")

  cache_from_var="$(service_name_cache_from_var "${service_name}")"
  if [[ -n "${!cache_from_var-}" ]]; then
    build_images+=("${!cache_from_var}")
  else
    build_images+=("")
  fi
done

if [[ ${#build_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config"
  build_image_override_file "${build_images[@]}" | tee "$override_file"
fi

services=()

# Parse the list of services to build into an array
while read -r line ; do
  [[ -n "$line" ]] && services+=("$line")
done <<< "$(plugin_read_list BUILD)"

build_params=(--pull)

if [[ "$(plugin_read_config NO_CACHE "false")" == "true" ]] ; then
  build_params+=(--no-cache)
fi

if [[ "$(plugin_read_config BUILD_PARALLEL "false")" == "true" ]] ; then
  build_params+=(--parallel)
fi

while read -r arg ; do
  [[ -n "${arg:-}" ]] && build_params+=("--build-arg" "${arg}")
done <<< "$(plugin_read_list ARGS)"

echo "+++ :docker: Building services ${services[*]}"
run_docker_compose -f "$override_file" build "${build_params[@]}" "${services[@]}"

if [[ -n "$image_repository" ]] ; then
  echo "~~~ :docker: Pushing built images to $image_repository"
  retry "$push_retries" run_docker_compose -f "$override_file" push "${services[@]}"

  # iterate over build images
  while [[ ${#build_images[@]} -gt 0 ]] ; do
    set_prebuilt_image "${build_images[0]}" "${build_images[1]}"

    # set aliases
    for service_alias in $(plugin_read_list BUILD_ALIAS) ; do
      set_prebuilt_image "$service_alias" "${build_images[1]}"
    done

    # pop-off the last build image
    build_images=("${build_images[@]:3}")
  done
fi
