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
up_params=()
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
  up_params+=(-f "$override_file")
fi

# If there are multiple services to pull, run it in parallel (although this is now the default)
if [[ ${#pull_services[@]} -gt 1 ]] ; then
  pull_params+=("pull" "--parallel" "${pull_services[@]}")
elif [[ ${#pull_services[@]} -eq 1 ]] ; then
  pull_params+=("pull" "${pull_services[0]}")
fi

# Pull down specified services
if [[ ${#pull_services[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Pulling services ${pull_services[0]}"
  retry "$pull_retries" run_docker_compose "${pull_params[@]}"

  # Sometimes docker-compose pull leaves unfinished ansi codes
  echo
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

tty_default='true'

# Set operating system specific defaults
if is_windows ; then
  tty_default='false'
fi

# Optionally disable allocating a TTY
if [[ "$(plugin_read_config TTY "$tty_default")" == "false" ]] ; then
  run_params+=(-T)
fi

# Optionally disable dependencies
if [[ "$(plugin_read_config DEPENDENCIES "true")" == "false" ]] ; then
  run_params+=(--no-deps)
fi

if [[ -n "$(plugin_read_config WORKDIR)" ]] ; then
  run_params+=("--workdir=$(plugin_read_config WORKDIR)")
fi

# Optionally run as specified username or uid
if [[ -n "$(plugin_read_config USER)" ]] ; then
  run_params+=("--user=$(plugin_read_config USER)")
fi

# Optionally disable ansi output
if [[ "$(plugin_read_config ANSI "true")" == "false" ]] ; then
  run_params+=(--no-ansi)
fi

# Enable alias support for networks
if [[ "$(plugin_read_config USE_ALIASES "false")" == "true" ]] ; then
  run_params+=(--use-aliases)
fi

# Optionally remove containers after run
if [[ "$(plugin_read_config RM "true")" == "true" ]]; then
  run_params+=(--rm)
fi

run_params+=("$run_service")

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_REQUIRE_PREBUILD:-}" =~ ^(true|on|1)$ ]] && [[ ! -f "$override_file" ]] ; then
  echo "+++ 🚨 No pre-built image found from a previous 'build' step for this service and config file."
  echo "The step specified that it was required"
  exit 1

elif [[ ! -f "$override_file" ]]; then
  echo "~~~ :docker: Building Docker Compose Service: $run_service" >&2
  echo "⚠️ No pre-built image found from a previous 'build' step for this service and config file. Building image..."

  # Ideally we'd do a pull with a retry first here, but we need the conditional pull behaviour here
  # for when an image and a build is defined in the docker-compose.ymk file, otherwise we try and
  # pull an image that doesn't exist
  run_docker_compose build --pull "$run_service"

  # Sometimes docker-compose pull leaves unfinished ansi codes
  echo
fi

# Start up service dependencies in a different header to keep the main run with less noise
if [[ "$(plugin_read_config DEPENDENCIES "true")" == "true" ]] ; then
  echo "~~~ :docker: Starting dependencies"
  if [[ ${#up_params[@]} -gt 0 ]] ; then
    run_docker_compose "${up_params[@]}" up -d --scale "${run_service}=0" "${run_service}"
  else
    run_docker_compose up -d --scale "${run_service}=0" "${run_service}"
  fi

  # Sometimes docker-compose leaves unfinished ansi codes
  echo
fi

shell=()
shell_disabled=1
result=()

if [[ -n "${BUILDKITE_COMMAND}" ]]; then
  shell_disabled=''
fi

# Handle shell being disabled
if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_SHELL:-}" =~ ^(false|off|0)$ ]] ; then
  shell_disabled=1

# Show a helpful error message if a string version of shell is used
elif [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_SHELL:-}" ]] ; then
  echo -n "🚨 The Docker Compose Plugin’s shell configuration option must be specified as an array. "
  echo -n "Please update your pipeline.yml to use an array, "
  echo "for example: [\"/bin/sh\", \"-e\", \"-u\"]."
  echo
  echo -n "Note that a shell will be inferred if one is required, so you might be able to remove"
  echo "the option entirely"
  exit 1

# Handle shell being provided as a string or list
elif plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMPOSE_SHELL ; then
  shell_disabled=''
  for arg in "${result[@]}" ; do
    shell+=("$arg")
  done
fi

# Set a default shell if one is needed
if [[ -z $shell_disabled ]] && [[ ${#shell[@]} -eq 0 ]] ; then
  if is_windows ; then
    shell=("CMD.EXE" "/c")
  else
    shell=("/bin/sh" "-e" "-c")
  fi
fi

command=()

# Show a helpful error message if string version of command is used
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND:-}" ]] ; then
  echo "🚨 The Docker Compose Plugin’s command configuration option must be an array."
  exit 1
fi

# Parse plugin command if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND ; then
  for arg in "${result[@]}" ; do
    command+=("$arg")
  done
fi

if [[ ${#command[@]} -gt 0 ]] && [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  echo "+++ Error: Can't use both a step level command and the command parameter of the plugin"
  exit 1
fi

# Assemble the shell and command arguments into the docker arguments

display_command=()

if [[ ${#shell[@]} -gt 0 ]] ; then
  for shell_arg in "${shell[@]}" ; do
    run_params+=("$shell_arg")
    display_command+=("$shell_arg")
  done
fi

if [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  run_params+=("${BUILDKITE_COMMAND}")
  display_command+=("'${BUILDKITE_COMMAND}'")
elif [[ ${#command[@]} -gt 0 ]] ; then
  for command_arg in "${command[@]}" ; do
    run_params+=("$command_arg")
    display_command+=("${command_arg}")
  done
fi

# Disable -e outside of the subshell; since the subshell returning a failure
# would exit the parent shell (here) early.
set +e

(
  echo "+++ :docker: Running ${display_command[*]:-} in service $run_service" >&2
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
  if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" != "false" ]] ; then

    # Get list of failed containers
    containers=()
    while read -r container ; do
      [[ -n "$container" ]] && containers+=("$container")
    done <<< "$(docker_ps_by_project -q)"

    failed_containers=()
    if [[ 0 != "${#containers[@]}" ]] ; then
      while read -r container ; do
        [[ -n "$container" ]] && failed_containers+=("$container")
      done <<< "$(docker inspect -f '{{if ne 0 .State.ExitCode}}{{.Name}}.{{.State.ExitCode}}{{ end }}' \
        "${containers[@]}")"
    fi

    if [[ 0 != "${#failed_containers[@]}" ]] ; then
      echo "+++ :warning: Some containers had non-zero exit codes"
      docker_ps_by_project \
        --format 'table {{.Label "com.docker.compose.service"}}\t{{ .ID }}\t{{ .Status }}'
    fi

    check_linked_containers_and_save_logs \
      "$run_service" "docker-compose-logs" \
      "$(plugin_read_config UPLOAD_CONTAINER_LOGS "on-error")"

    if [[ -d "docker-compose-logs" ]] && test -n "$(find docker-compose-logs/ -maxdepth 1 -name '*.log' -print)"; then
      echo "~~~ Uploading linked container logs"
      buildkite-agent artifact upload "docker-compose-logs/*.log"
    fi
  fi
fi

return $exitcode
