#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

run_service="$(plugin_read_config RUN)"
container_name="$(docker_compose_project_name)_${run_service}_build_${BUILDKITE_BUILD_NUMBER}"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"

cleanup() {
  echo "~~~ :docker: Cleaning up after docker-compose" >&2
  compose_cleanup
}

# clean up docker containers on EXIT
if [[ "$(plugin_read_config CLEANUP "true")" == "true" ]] ; then
  trap cleanup EXIT
fi

test -f "$override_file" && rm "$override_file"

run_params=()
pull_params=()
pull_services=()
prebuilt_candidates=("$run_service")

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
service_overrides=()
prebuilt_services=()

# We look for a prebuilt images for all the pull services and the run_service.
for service_name in "${prebuilt_candidates[@]}" ; do
  if prebuilt_image=$(get_prebuilt_image "$service_name") ; then
    echo "~~~ :docker: Found a pre-built image for $service_name"
    service_overrides+=("$service_name" "$prebuilt_image" "")
    prebuilt_services+=("$service_name")

    # If it's prebuilt, we need to pull it down
    if [[ -z "${pull_services:-}" ]] || ! in_array "$service_name" "${pull_services[@]}" ; then
      pull_services+=("$service_name")
    fi
  fi
done

# Handle cache_from directive for run service
cache_from="$(plugin_read_config CACHE_FROM)"
if [[ -n "${cache_from}" ]] ; then
  # The cache_from format is either service or service:image:tag
  IFS=':' read -r -a cache_from_tokens <<< "$cache_from"
  cache_from_service_name=${cache_from_tokens[0]}
  cache_from_service_image=$(IFS=':'; echo "${cache_from_tokens[*]:1}")

  # For run, cache_from and a previously build image are mutually exclusive
  if [[ -n "${prebuilt_services[*]:-}" ]] && in_array "$run_service" "${prebuilt_services[@]}" ; then
    echo "+++ :warn: Service $run_service has a prebuilt image, so can't also have cache_from set"
    exit 1
  fi

  # Only look up the prebuilt image if the cache_from directive is only a service name
  if [[ -z "$cache_from_service_image" ]] && cache_from_service_image=$(get_prebuilt_image "$cache_from_service_name") ; then
    echo "~~~ :docker: Using prebuilt image of $cache_from_service_name as cache_from for $run_service"

    # Override the cache_from service and pull it
    service_overrides+=("$cache_from_service_name" "$cache_from_service_image" "")
    pull_services+=("$cache_from_service_name")

    # Now override the run service with an empty image, but a cache_from
    service_overrides+=("$run_service" "" "$cache_from_service_image")
  fi
fi

# If service overrides, generate a docker-compose file
if [[ ${#service_overrides[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating docker-compose override file for prebuilt services"
  build_image_override_file "${service_overrides[@]}" | tee "$override_file"
  run_params+=(-f "$override_file")
  pull_params+=(-f "$override_file")
fi

# If there are multiple services to pull, run it in parallel
if [[ ${#pull_services[@]} -gt 1 ]] ; then
  pull_params+=("pull" "--parallel" "${pull_services[@]}")
elif [[ ${#pull_services[@]} -eq 1 ]] ; then
  pull_params+=("pull" "${pull_services[0]}")
fi

# Pull down specified services
if [[ ${#pull_services[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Pulling services ${pull_services[0]}"
  retry "$pull_retries" run_docker_compose "${pull_params[@]}"
fi

# We set a predictable container name so we can find it and inspect it later on
run_params+=("run" "--name" "$container_name")

# append env vars provided in ENV or ENVIRONMENT, these are newline delimited
while IFS=$'\n' read -r env ; do
  [[ -n "${env:-}" ]] && run_params+=("-e" "${env}")
done <<< "$(printf '%s\n%s' \
  "$(plugin_read_list ENV)" \
  "$(plugin_read_list ENVIRONMENT)")"

# Optionally disable allocating a TTY
if [[ "$(plugin_read_config TTY "true")" == "false" ]] ; then
  run_params+=(-T)
fi

# Optionally disable dependencies
if [[ "$(plugin_read_config DEPENDENCIES "true")" == "false" ]] ; then
  run_params+=(--no-deps)
fi

run_params+=("$run_service")

if [[ ! -f "$override_file" ]]; then
  echo "~~~ :docker: Building Docker Compose Service: $run_service" >&2
  run_docker_compose build --pull "$run_service"
fi

# Disable -e outside of the subshell; since the subshell returning a failure
# would exit the parent shell (here) early.
set +e

(
  # Reset bash to the default IFS with no glob expanding and no failing on error
  unset IFS
  set -f

  # The eval statements below are used to allow $BUILDKITE_COMMAND to be interpolated correctly
  # When paired with -f we ensure that it word splits correctly, e.g bash -c "pwd" should split
  # into [bash, -c, "pwd"]. Eval ends up the simplest way to do this, and when paired with the
  # set -f above we ensure globs aren't expanded (imagine a command like `cat *`, which bash would
  # helpfully expand prior to passing it to docker-compose)

  echo "+++ :docker: Running command in Docker Compose service: $run_service" >&2
  eval "run_docker_compose \${run_params[@]} $BUILDKITE_COMMAND"
)

exitcode=$?

# Restore -e as an option.
set -e

if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode"
else
  echo "~~~ :docker: Container exited normally"
fi

if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" == "true" ]] ; then
  echo "~~~ Checking linked containers"
  docker_ps_by_project \
    --format 'table {{.Label "com.docker.compose.service"}}\t{{ .ID }}\t{{ .Status }}'
  check_linked_containers_and_save_logs "docker-compose-logs" "$exitcode"

  echo "~~~ Uploading container logs as artifacts"
  buildkite-agent artifact upload "docker-compose-logs/*.log"
fi

exit $exitcode
