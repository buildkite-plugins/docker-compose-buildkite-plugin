#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

run_service="$(plugin_read_config RUN)"
container_name="$(docker_compose_project_name)_${run_service}_build_${BUILDKITE_BUILD_NUMBER}"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"

expand_headers_on_error() {
  echo "^^^ +++"
}
trap expand_headers_on_error ERR

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
prebuilt_service_overrides=()
prebuilt_services=()

# We look for a prebuilt images for all the pull services and the run_service.
for service_name in "${prebuilt_candidates[@]}" ; do
  if prebuilt_image=$(get_prebuilt_image "$service_name") ; then
    echo "~~~ :docker: Found a pre-built image for $service_name"
    prebuilt_service_overrides+=("$service_name" "$prebuilt_image" "")
    prebuilt_services+=("$service_name")

    # If it's prebuilt, we need to pull it down
    if [[ -z "${pull_services:-}" ]] || ! in_array "$service_name" "${pull_services[@]}" ; then
      pull_services+=("$service_name")
   fi
  fi
done

# If there are any prebuilts, we need to generate an override docker-compose file
if [[ ${#prebuilt_services[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating docker-compose override file for prebuilt services"
  build_image_override_file "${prebuilt_service_overrides[@]}" | tee "$override_file"
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

while IFS=$'\n' read -r vol ; do
  [[ -n "${vol:-}" ]] && run_params+=("-v" "$(expand_relative_volume_path "$vol")")
done <<< "$(plugin_read_list VOLUMES)"

# Parse BUILDKITE_DOCKER_DEFAULT_VOLUMES delimited by semi-colons, normalized to
# ignore spaces and leading or trailing semi-colons
IFS=';' read -r -a default_volumes <<< "${BUILDKITE_DOCKER_DEFAULT_VOLUMES:-}"
for vol in "${default_volumes[@]:-}" ; do
  trimmed_vol="$(echo -n "$vol" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//')"
  [[ -n "$trimmed_vol" ]] && run_params+=("-v" "$(expand_relative_volume_path "$trimmed_vol")")
done

# Optionally disable allocating a TTY
if [[ "$(plugin_read_config TTY "true")" == "false" ]] ; then
  run_params+=(-T)
fi

# Optionally disable dependencies
if [[ "$(plugin_read_config DEPENDENCIES "true")" == "false" ]] ; then
  run_params+=(--no-deps)
fi

if [[ -n "$(plugin_read_config WORKDIR)" ]] ; then
  run_params+=("--workdir=$(plugin_read_config WORKDIR)")
fi

# Optionally disable ansi output
if [[ "$(plugin_read_config ANSI "true")" == "false" ]] ; then
  run_params+=(--no-ansi)
fi

run_params+=("$run_service")

if [[ ! -f "$override_file" ]]; then
  echo "~~~ :docker: Building Docker Compose Service: $run_service" >&2
  echo "⚠️ No pre-built image found from a previous 'build' step for this service and config file. Building image..."
  run_docker_compose build --pull "$run_service"
fi

# Disable -e outside of the subshell; since the subshell returning a failure
# would exit the parent shell (here) early.
set +e

(
  # Reset bash to the default IFS
  unset IFS

  # Because we receive $BUILDKITE_COMMAND as a single string, it needs to be tokenized as a shell
  # would to respect things like quoted strings. Previously we used eval to do this with some
  # careful control around preventing glob expansion, but this ends up being difficult to get just
  # right and also very risky. The new implementation uses xargs and printf to tokenize the string,
  # which is portable and much harder to shoot ourselves in the foot 🎉

  while IFS= read -rd '' token; do
    [[ -n "$token" ]] && run_params+=("$token")
  done < <(xargs printf '%s\0' <<< "$BUILDKITE_COMMAND")

  echo "+++ :docker: Running command in Docker Compose service: $run_service" >&2
  run_docker_compose "${run_params[@]}"
)

exitcode=$?

# Restore -e as an option.
set -e

if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode"
fi

if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
  if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" == "true" ]] ; then
    docker_ps_by_project \
      --format 'table {{.Label "com.docker.compose.service"}}\t{{ .ID }}\t{{ .Status }}'
    check_linked_containers_and_save_logs "docker-compose-logs" "$exitcode"

    if [[ -d "docker-compose-logs" ]] && test -n "$(find docker-compose-logs/ -maxdepth 1 -name '*.log' -print)"; then
      echo "~~~ Uploading linked container logs"
      buildkite-agent artifact upload "docker-compose-logs/*.log"
    fi
  fi
fi

exit $exitcode
