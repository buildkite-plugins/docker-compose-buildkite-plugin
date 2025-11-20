#!/bin/bash
set -ueo pipefail

override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
build_images=()
build_params=()

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

if [[ "$(plugin_read_config BUILDKIT "true")" == "true" ]]; then
  export DOCKER_BUILDKIT=1
  export COMPOSE_DOCKER_CLI_BUILD=1
  export BUILDKIT_PROGRESS=plain
fi

# Check if push-on-build is enabled
push_on_build="$(plugin_read_config BUILDER_PUSH_ON_BUILD "false")"

# Log cache-from conversion for multi-arch builds
if [[ "${push_on_build}" == "true" ]]; then
  cache_from_count=$(plugin_read_list CACHE_FROM | wc -l)
  if [[ "${cache_from_count}" -gt 0 ]]; then
    echo "~~~ :docker: Converting cache-from registry references to type=registry format for multi-arch build"
  fi
fi

get_caches_for_service() {
  local service="$1"
  local push_on_build="${2:-false}"

  # Read any cache-from parameters provided
  # If no-cache is set skip pulling the cache-from images
  if [[ "$(plugin_read_config NO_CACHE "false")" == "false" ]] ; then
    for line in $(plugin_read_list CACHE_FROM) ; do
      IFS=':' read -r -a tokens <<< "$line"
      service_name=${tokens[0]}
      service_image=$(IFS=':'; echo "${tokens[*]:1}")

      if [ "${service_name}" == "${service}" ]; then
        # Auto-convert cache-from to registry format for multi-arch builds
        if [[ "${push_on_build}" == "true" ]]; then
          # Check if CACHE-SPEC contains / or . (indicates registry) AND doesn't already start with type=
          if [[ "${service_image}" =~ [/.] ]] && [[ ! "${service_image}" =~ ^type= ]]; then
            echo "type=registry,ref=${service_image}"
          else
            echo "$service_image"
          fi
        else
          echo "$service_image"
        fi
      fi
    done
  fi
}

get_caches_to_service() {
  local service="$1"

  # Read any cache-to parameters provided
  for line in $(plugin_read_list CACHE_TO) ; do
    IFS=':' read -r -a tokens <<< "$line"
    service_name=${tokens[0]}
    service_image=$(IFS=':'; echo "${tokens[*]:1}")

    if [ "${service_name}" == "${service}" ]; then
      echo "$service_image"
    fi
  done
}


# Run through all images in the build property, either a single item or a list
# and build up a list of service name, image name and optional cache-froms and cache-tos to
# write into a docker-compose override file

# If push-on-build is enabled, build a map of services to their push targets
declare -A service_push_images
if [[ "${push_on_build}" == "true" ]]; then
  for line in $(plugin_read_list PUSH) ; do
    if [[ "$(plugin_read_config EXPAND_PUSH_VARS 'false')" == "true" ]]; then
      push_target=$(eval echo "$line")
    else
      push_target="$line"
    fi
    
    IFS=':' read -r -a tokens <<< "$push_target"
    service_name=${tokens[0]}
    
    # Store only the first push target for each service (for the override file)
    if [[ -z "${service_push_images[$service_name]:-}" ]] && [[ ${#tokens[@]} -gt 1 ]]; then
      target_image="$(IFS=:; echo "${tokens[*]:1}")"
      service_push_images[$service_name]="$target_image"
    fi
  done
fi

for service_name in $(plugin_read_list BUILD) ; do
  target="$(plugin_read_config TARGET "")"
  image_name="" # no longer used here
  
  # If push-on-build, set the image name from push targets
  if [[ "${push_on_build}" == "true" ]] && [[ -n "${service_push_images[$service_name]:-}" ]]; then
    image_name="${service_push_images[$service_name]}"
  fi

  cache_from=()
  for cache_line in $(get_caches_for_service "$service_name" "$push_on_build"); do
    cache_from+=("$cache_line")
  done

  cache_to=()
  for cache_line in $(get_caches_to_service "$service_name"); do
    cache_to+=("$cache_line")
  done

  labels=()
  while read -r label ; do
    [[ -n "${label:-}" ]] && labels+=("${label}")
  done <<< "$(plugin_read_list BUILD_LABELS)"

  platforms=()
  while read -r platform ; do
    [[ -n "${platform:-}" ]] && platforms+=("${platform}")
  done <<< "$(plugin_read_list PLATFORMS)"

  if [[ -n "${image_name}" ]] || [[ -n "${target}" ]] || [[ "${#labels[@]}" -gt 0 ]] || [[ "${#cache_to[@]}" -gt 0 ]] || [[ "${#cache_from[@]}" -gt 0 ]] || [[ "${#platforms[@]}" -gt 0 ]]; then
    build_images+=("$service_name" "${image_name}" "${target}")

    build_images+=("${#cache_from[@]}")
    if [[ "${#cache_from[@]}" -gt 0 ]]; then
      build_images+=("${cache_from[@]}")
    fi

    build_images+=("${#cache_to[@]}")
    if [[ "${#cache_to[@]}" -gt 0 ]]; then
      build_images+=("${cache_to[@]}")
    fi

    build_images+=("${#labels[@]}")
    if [[ "${#labels[@]}" -gt 0 ]]; then
      build_images+=("${labels[@]}")
    fi

    build_images+=("${#platforms[@]}")
    if [[ "${#platforms[@]}" -gt 0 ]]; then
      build_images+=("${platforms[@]}")
    fi
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

if [[ -f "${override_file}" ]]; then
  build_params+=(-f "${override_file}")
fi

build_params+=(build)

if [[ ! "$(plugin_read_config SKIP_PULL "false")" == "true" ]] ; then
  build_params+=(--pull)
fi

if [[ -n "$(plugin_read_config BUILDER_NAME "")" ]] && [[ "$(plugin_read_config BUILDER_USE "false")" == "true" ]]; then
  build_params+=("--builder" "$(plugin_read_config BUILDER_NAME "")")
fi

if [[ "$(plugin_read_config NO_CACHE "false")" == "true" ]] ; then
  build_params+=(--no-cache)
fi

if [[ "$(plugin_read_config BUILD_PARALLEL "false")" == "true" ]] ; then
  build_params+=(--parallel)
fi

if [[ "$(plugin_read_config BUILDKIT_INLINE_CACHE "false")" == "true" ]] ; then
  build_params+=("--build-arg" "BUILDKIT_INLINE_CACHE=1")
fi

if [[ "$(plugin_read_config WITH_DEPENDENCIES "false")" == "true" ]] ; then
  build_params+=(--with-dependencies)
fi

if [[ "$(plugin_read_config SSH "false")" != "false" ]] ; then
  if [[ "${DOCKER_BUILDKIT:-}" != "1" && "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION:-2}" != "2" ]]; then
    echo "🚨 You can not use the ssh option if you are not using buildkit"
    exit 1
  fi

  SSH_CONTEXT="$(plugin_read_config SSH)"
  if [[ "${SSH_CONTEXT}" == "true" ]]; then
    # ssh option was a boolean
    SSH_CONTEXT='default'
  fi
  build_params+=(--ssh "${SSH_CONTEXT}")
fi

while read -r arg ; do
  [[ -n "${arg:-}" ]] && build_params+=("--build-arg" "${arg}")
done <<< "$(plugin_read_list ARGS)"

# Handle push-on-build for multi-arch builds
if [[ "${push_on_build}" == "true" ]]; then
  # Validate all push targets are in build list and collect all tags for each service
  declare -A service_first_tag
  declare -A service_additional_tags
  push_targets=()
  
  for line in $(plugin_read_list PUSH) ; do
    if [[ "$(plugin_read_config EXPAND_PUSH_VARS 'false')" == "true" ]]; then
      push_target=$(eval echo "$line")
    else
      push_target="$line"
    fi
    
    IFS=':' read -r -a tokens <<< "$push_target"
    service_name=${tokens[0]}
    
    # Validate service in push list exists in build list
    if ! in_array "${service_name}" "${services[@]}"; then
      echo "+++ 🚨 Service '${service_name}' specified in push but not in build. With push-on-build, all pushed services must be built."
      exit 1
    fi
    
    # Track unique services
    if ! in_array "${service_name}" "${push_targets[@]}"; then
      push_targets+=("${service_name}")
    fi
    
    # Store first tag for override file, additional tags for manual push
    if [[ ${#tokens[@]} -gt 1 ]] ; then
      target_image="$(IFS=:; echo "${tokens[*]:1}")"
      if [[ -z "${service_first_tag[$service_name]:-}" ]]; then
        service_first_tag[$service_name]="$target_image"
      else
        # Append additional tags with delimiter
        if [[ -z "${service_additional_tags[$service_name]:-}" ]]; then
          service_additional_tags[$service_name]="$target_image"
        else
          service_additional_tags[$service_name]="${service_additional_tags[$service_name]}|${target_image}"
        fi
      fi
    fi
  done
  
  # Add --push flag for multi-arch builds
  build_params+=(--push)
fi

echo "${group_type} :docker: Building services ${services[*]}"
run_docker_compose "${build_params[@]}" "${services[@]}"

# Handle additional tags and set metadata after successful build when using push-on-build
if [[ "${push_on_build}" == "true" ]]; then
  prebuilt_image_namespace="$(plugin_read_config PREBUILT_IMAGE_NAMESPACE 'docker-compose-plugin-')"
  push_retries="$(plugin_read_config PUSH_RETRIES "0")"
  
  for service_name in "${push_targets[@]}"; do
    # Get the first tag (which was already pushed by docker compose build --push)
    first_tag="${service_first_tag[$service_name]:-}"
    
    if [[ -n "${first_tag}" ]]; then
      source_image="${first_tag}"
      echo "~~~ :docker: Setting prebuilt image metadata for ${service_name}: ${source_image}"
      set_prebuilt_image "${prebuilt_image_namespace}" "${service_name}" "${source_image}"
      
      # Push additional tags if any exist
      additional_tags="${service_additional_tags[$service_name]:-}"
      if [[ -n "${additional_tags}" ]]; then
        echo "~~~ :docker: Tagging and pushing additional images for ${service_name}"
        IFS='|' read -r -a tags_array <<< "$additional_tags"
        for additional_tag in "${tags_array[@]}"; do
          echo "~~~ :docker: Pushing additional tag: ${additional_tag}"
          # Use docker buildx imagetools create to create additional tags from the multi-arch image
          retry "$push_retries" plugin_prompt_and_run docker buildx imagetools create --tag "${additional_tag}" "${source_image}"
        done
      fi
    else
      # For services without explicit tags, get the image name from compose config
      compose_image="$(compose_image_for_service "${service_name}")"
      if [[ -n "${compose_image}" ]]; then
        echo "~~~ :docker: Setting prebuilt image metadata for ${service_name}: ${compose_image}"
        set_prebuilt_image "${prebuilt_image_namespace}" "${service_name}" "${compose_image}"
      else
        # Fall back to default compose image name if no image is set
        default_image="$(default_compose_image_for_service "${service_name}")"
        echo "~~~ :docker: Setting prebuilt image metadata for ${service_name}: ${default_image}"
        set_prebuilt_image "${prebuilt_image_namespace}" "${service_name}" "${default_image}"
      fi
    fi
  done
  
  # Process build-alias services using existing loop
  for service_alias in $(plugin_read_list BUILD_ALIAS) ; do
    # For build-alias, use the first pushed service's image
    if [[ ${#push_targets[@]} -gt 0 ]]; then
      first_service="${push_targets[0]}"
      first_tag="${service_first_tag[$first_service]:-}"
      if [[ -n "${first_tag}" ]]; then
        echo "~~~ :docker: Setting prebuilt image metadata for alias ${service_alias}: ${first_tag}"
        set_prebuilt_image "${prebuilt_image_namespace}" "${service_alias}" "${first_tag}"
      fi
    fi
  done
fi
