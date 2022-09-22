#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

run_service="$(plugin_read_config RUN)"
container_name="$(docker_compose_project_name)_${run_service}_build_${BUILDKITE_BUILD_NUMBER}"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"
pull_retries="$(plugin_read_config PULL_RETRIES "0")"
mount_ssh_agent=''

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
    prebuilt_service_overrides+=("$service_name" "$prebuilt_image" 0)
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

# Optionally disable ansi output
if [[ "$(plugin_read_config ANSI "true")" == "false" ]] ; then
  run_params+=(--no-ansi)
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

# If there's a git mirror, mount it so that git references can be followed.
if [[ -n "${BUILDKITE_REPO_MIRROR:-}" ]]; then
  run_params+=("-v" "$BUILDKITE_REPO_MIRROR:$BUILDKITE_REPO_MIRROR:ro")
fi

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

# Can't set both user and propagate-uid-gid
if [[ -n "$(plugin_read_config USER)" ]] && [[ -n "$(plugin_read_config PROPAGATE_UID_GID)" ]]; then
  echo "+++ Error: Can't set both user and propagate-uid-gid"
  exit 1
fi

# Optionally run as specified username or uid
if [[ -n "$(plugin_read_config USER)" ]] ; then
  run_params+=("--user=$(plugin_read_config USER)")
fi

# Optionally run as specified username or uid
if [[ "$(plugin_read_config PROPAGATE_UID_GID "false")" == "true" ]] ; then
  run_params+=("--user=$(id -u):$(id -g)")
fi

# Enable alias support for networks
if [[ "$(plugin_read_config USE_ALIASES "false")" == "true" ]] ; then
  run_params+=(--use-aliases)
fi

# Optionally remove containers after run
if [[ "$(plugin_read_config RM "true")" == "true" ]]; then
  run_params+=(--rm)
fi

# Optionally sets --entrypoint
if [[ -n "$(plugin_read_config ENTRYPOINT)" ]] ; then
  run_params+=(--entrypoint)
  run_params+=("$(plugin_read_config ENTRYPOINT)")
fi

# Mount ssh-agent socket and known_hosts
if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_SSH_AGENT:-$mount_ssh_agent}" =~ ^(true|on|1)$ ]] ; then
  if [[ -z "${SSH_AUTH_SOCK:-}" ]] ; then
    echo "+++ 🚨 \$SSH_AUTH_SOCK isn't set, has ssh-agent started?"
    exit 1
  fi
  if [[ ! -S "${SSH_AUTH_SOCK}" ]] ; then
    echo "+++ 🚨 There isn't any file at ${SSH_AUTH_SOCK}, has ssh-agent started?"
    exit 1
  fi
  if [[ ! -S "${SSH_AUTH_SOCK}" ]] ; then
    echo "+++ 🚨 The file at ${SSH_AUTH_SOCK} isn't a socket, has ssh-agent started?"
    exit 1
  fi
  run_params+=(
    "-e" "SSH_AUTH_SOCK=/ssh-agent"
    "-v" "${SSH_AUTH_SOCK}:/ssh-agent"
    "-v" "${HOME}/.ssh/known_hosts:/root/.ssh/known_hosts"
  )
fi

# Optionally handle the mount-buildkite-agent option
if [[ "$(plugin_read_config MOUNT_BUILDKITE_AGENT "false")" == "true" ]]; then
  if [[ -z "${BUILDKITE_AGENT_BINARY_PATH:-}" ]] ; then
    if ! command -v buildkite-agent >/dev/null 2>&1 ; then
      echo -n "+++ 🚨 Failed to find buildkite-agent in PATH to mount into container, "
      echo "you can disable this behaviour with 'mount-buildkite-agent:false'"
    else
      BUILDKITE_AGENT_BINARY_PATH=$(command -v buildkite-agent)
    fi
  fi
fi

# Mount buildkite-agent if we have a path for it
if [[ -n "${BUILDKITE_AGENT_BINARY_PATH:-}" ]] ; then
  run_params+=(
    "-e" "BUILDKITE_JOB_ID"
    "-e" "BUILDKITE_BUILD_ID"
    "-e" "BUILDKITE_AGENT_ACCESS_TOKEN"
    "-v" "$BUILDKITE_AGENT_BINARY_PATH:/usr/bin/buildkite-agent"
  )
fi

run_params+=("$run_service")

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
  run_docker_compose build "${build_params[@]}" "$run_service"

  # Sometimes docker-compose pull leaves unfinished ansi codes
  echo
fi

dependency_exitcode=0
if [[ "$(plugin_read_config DEPENDENCIES "true")" == "true" ]] ; then

  # Start up service dependencies in a different header to keep the main run with less noise
  echo "~~~ :docker: Starting dependencies"
  if [[ ${#up_params[@]} -gt 0 ]] ; then
    run_docker_compose "${up_params[@]}" up -d --scale "${run_service}=0" "${run_service}" || dependency_exitcode=$?
  else
    run_docker_compose up -d --scale "${run_service}=0" "${run_service}" || dependency_exitcode=$?
  fi

  # Sometimes docker-compose leaves unfinished ansi codes
  echo
fi

if [[ $dependency_exitcode -ne 0 ]] ; then
  # Dependent services failed to start.
  echo "^^^ +++"
  echo "+++ 🚨 Failed to start dependencies"

  if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
    print_failed_container_information

    upload_container_logs "$run_service"
  fi

  return $dependency_exitcode
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
  echo "+++ :warning: Failed to run command, exited with $exitcode, run params:"
  echo "${run_params[@]}"
fi

if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
  if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" != "false" ]] ; then
    print_failed_container_information

    upload_container_logs "$run_service"
  fi
fi

return $exitcode
