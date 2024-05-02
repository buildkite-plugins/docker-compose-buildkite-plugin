#!/bin/bash
set -uo pipefail

function pull() {
  prebuilt_candidates=("$1")

  pull_services=()
  pull_params=()

  override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
  pull_retries="$(plugin_read_config PULL_RETRIES "0")"

  # Build a list of services that need to be pulled down
  while read -r name ; do
    if [[ -n "$name" ]] ; then
      pull_services+=("$name")

      if ! in_array "$name" "${prebuilt_candidates[@]}" ; then
        prebuilt_candidates+=("$name")
      fi
    fi
  done <<< "$(plugin_read_list PULL)"

  # A list of tuples of [service image cache_from] for build_image_override_file
  prebuilt_service_overrides=()
  prebuilt_services=()

  # We look for a prebuilt images for all the pull services and the run_service.
  prebuilt_image_override="$(plugin_read_config RUN_IMAGE)"
  for service_name in "${prebuilt_candidates[@]}" ; do
    if [[ -n "$prebuilt_image_override" ]] && [[ "$service_name" == "$1" ]] ; then
      echo "~~~ :docker: Overriding run image for $service_name"
      prebuilt_image="$prebuilt_image_override"
    elif prebuilt_image=$(get_prebuilt_image "$service_name") ; then
      echo "~~~ :docker: Found a pre-built image for $service_name"
    fi

    if [[ -n "$prebuilt_image" ]] ; then
      prebuilt_service_overrides+=("$service_name" "$prebuilt_image" "" 0 0)
      prebuilt_services+=("$service_name")

      # If it's prebuilt, we need to pull it down
      if [[ -z "${pull_services:-}" ]] || ! in_array "$service_name" "${pull_services[@]}" ; then
        pull_services+=("$service_name")
    fi
    fi
  done

  exitcode=1
  # If there are any prebuilts, we need to generate an override docker-compose file
  if [[ ${#prebuilt_services[@]} -gt 0 ]] ; then
    echo "~~~ :docker: Creating docker-compose override file for prebuilt services"
    build_image_override_file "${prebuilt_service_overrides[@]}" | tee "$override_file"
    pull_params+=(-f "$override_file")
    exitcode=0
  fi

  # If there are multiple services to pull, run it in parallel (although this is now the default)
  if [[ ${#pull_services[@]} -gt 1 ]] ; then
    pull_params+=("pull" "--parallel" "${pull_services[@]}")
  elif [[ ${#pull_services[@]} -eq 1 ]] ; then
    pull_params+=("pull" "${pull_services[0]}")
  fi

  # Pull down specified services
  if [[ ${#pull_services[@]} -gt 0 ]] && [[ "$(plugin_read_config SKIP_PULL "false")" != "true" ]]; then
    echo "~~~ :docker: Pulling services ${pull_services[0]}"
    retry "$pull_retries" run_docker_compose "${pull_params[@]}"
  fi

  echo "done pulling. exitcode: $exitcode"
  return $exitcode
}