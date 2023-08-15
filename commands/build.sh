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

service_name_group_name_cache_from_var() {
  local service_name="$1"
  local group_index="$2"
  echo "group_cache_from__${service_name//-/_}__${group_index//-/_}"
}

count_of_named_array() {
  local tmp="$1[@]"
  local copy=( "${!tmp}" )
  echo "${#copy[@]}"
}

named_array_values() {
  local tmp="$1[@]"
  local copy=( "${!tmp}" )
  echo "${copy[@]}"
}

if [[ -z "$image_repository" ]] ; then
  echo "+++ ⚠️ Build step missing image-repository setting"
  echo "This build step has no image-repository set. Without an image-repository, the Docker image won't be pushed to a repository, and won't be automatically used by any run steps."
fi

# Read any cache-from parameters provided and pull down those images first
# If no-cache is set skip pulling the cache-from images
if [[ "$(plugin_read_config NO_CACHE "false")" == "false" ]] ; then
  for line in $(plugin_read_list CACHE_FROM) ; do
    IFS=':' read -r -a tokens <<< "$line"
    service_name=${tokens[0]}
    service_image=$(IFS=':'; echo "${tokens[*]:1:2}")
    cache_from_group_name=$(IFS=':'; echo "${tokens[*]:3}")
    if [[ -z "$cache_from_group_name" ]]; then
      cache_from_group_name=":default:"
    fi
    # The variable with this name will hold an array of group names:
    cache_image_name="$(service_name_cache_from_var "$service_name")"

    # If we're using prior images and we find an exact match, terminate and skip
    # all further processing. This won't work for a multi-image build step, only
    # a single service can be built this way
    if [[ "$(plugin_read_config USE_PRIOR_IMAGE "false")" == "true" ]] && \
      docker manifest inspect "$service_image" > /dev/null; then
        echo ":docker: Found an image! Marking and skipping $service_image"
        set_prebuilt_image "$service_name" "$service_image"

        for service_alias in $(plugin_read_list BUILD_ALIAS) ; do
          set_prebuilt_image "$service_alias" "$service_image"
        done

        exit 0
    fi

    if [[ -n ${!cache_image_name+x} ]]; then
      if [[ "$(named_array_values "${cache_image_name}")" =~ ${cache_from_group_name} ]]; then
        continue # skipping since there's already a pulled cache image for this service+group
      fi
    fi

    echo "~~~ :docker: Pulling cache image for $service_name (group ${cache_from_group_name})"
    if retry "$pull_retries" plugin_prompt_and_run docker pull "$service_image" ; then
      if [[ -z "${!cache_image_name+x}" ]]; then
        declare -a "$cache_image_name"
        cache_image_length=0
      else
        cache_image_length="$(count_of_named_array "${cache_image_name}")"
      fi

      declare "$cache_image_name+=( $cache_from_group_name )"
      # The variable with this name will hold the image for the this group
      # (based on index into the array of group names):
      cache_from_group_var="$(service_name_group_name_cache_from_var "$service_name" "${cache_image_length}")"
      printf -v "$cache_from_group_var" "%s" "$service_image"
    else
      echo "!!! :docker: Pull failed. $service_image will not be used as a cache for $service_name"
    fi
  done
fi

# Run through all images in the build property, either a single item or a list
# and build up a list of service name, image name and optional cache-froms to
# write into a docker-compose override file
service_idx=0
for service_name in $(plugin_read_list BUILD) ; do
  image_name=$(build_image_name "${service_name}" "${service_idx}")
  service_idx=$((service_idx+1))

  if [[ -n "$image_repository" ]] ; then
    image_name="${image_repository}:${image_name}"
  fi

  build_images+=("$service_name" "$image_name")

  cache_from_var="$(service_name_cache_from_var "${service_name}")"
  if [[ -n "${!cache_from_var-}" ]]; then
    cache_from_length="$(count_of_named_array "${cache_from_var}")"
    build_images+=("${cache_from_length}")

    for i in $(seq 0 "$((cache_from_length-1))"); do
      cache_from_group_var="$(service_name_group_name_cache_from_var "$service_name" "$i")"
      build_images+=("${!cache_from_group_var}")
    done
  else
    build_images+=(0)
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
    # 3 for service, image, num_cache_from; plus num_cache_from
    build_images=("${build_images[@]:(3 + ${build_images[2]})}")
  done
fi
