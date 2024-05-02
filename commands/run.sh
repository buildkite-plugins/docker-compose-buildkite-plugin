#!/bin/bash
set -uo pipefail

. "$DIR/../lib/run.bash"
. "$DIR/../commands/pull.sh"
. "$DIR/../commands/run_cmd_generator.sh"

# Can't set both user and propagate-uid-gid
if [[ -n "$(plugin_read_config USER)" ]] && [[ -n "$(plugin_read_config PROPAGATE_UID_GID)" ]]; then
  echo "+++ Error: Can't set both user and propagate-uid-gid"
  exit 1
fi

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

run_service="$(plugin_read_config RUN)"
container_name="$(docker_compose_project_name)_${run_service}_build_${BUILDKITE_BUILD_NUMBER}"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"

expand_headers_on_error() {
  echo "^^^ +++"
}
trap expand_headers_on_error ERR

test -f "$override_file" && rm "$override_file"

pull "$run_service"
pulled_status=$?

if [[ ! -f "$override_file" ]] ; then
  echo "+++ 🚨 No pre-built image found from a previous 'build' step for this service and config file."

  if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_REQUIRE_PREBUILD:-}" =~ ^(true|on|1)$ ]]; then
    echo "The step specified that it was required"
    exit 1
  fi
fi

up_params=()

run_params=()
generate_run_args $container_name $pulled_status

run_params+=("$run_service")



up_params+=("up")  # this ensures that the array has elements to avoid issues with bash 4.3

if [[ "$(plugin_read_config WAIT "false")" == "true" ]] ; then
  up_params+=("--wait")
fi

if [[ "$(plugin_read_config QUIET_PULL "false")" == "true" ]] ; then
  up_params+=("--quiet-pull")
fi

dependency_exitcode=0


run_dependencies="true"
# Optionally disable dependencies
if [[ "$(plugin_read_config DEPENDENCIES "true")" == "false" ]] ; then
  run_params+=(--no-deps)
  run_dependencies="false"
elif [[ "$(plugin_read_config PRE_RUN_DEPENDENCIES "true")" == "false" ]]; then
  run_dependencies="false"
fi

if [[ "${run_dependencies}" == "true" ]] ; then
  # Start up service dependencies in a different header to keep the main run with less noise
  echo "~~~ :docker: Starting dependencies"
  run_docker_compose "${up_params[@]}" -d --scale "${run_service}=0" "${run_service}" || dependency_exitcode=$?
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
  # else
    # shell=("/bin/sh" "-e" "-c")
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
  if [[ $(echo "$BUILDKITE_COMMAND" | wc -l) -gt 1 ]]; then
    # An array of commands in the step will be a single string with multiple lines
    # This breaks a lot of things here so we will print a warning for user to be aware
    echo "⚠️  Warning: The command received has multiple lines."
    echo "⚠️           The Docker Compose Plugin does not correctly support step-level array commands."
  fi
  run_params+=("${BUILDKITE_COMMAND}")
  display_command+=("'${BUILDKITE_COMMAND}'")
elif [[ ${#command[@]} -gt 0 ]] ; then
  for command_arg in "${command[@]}" ; do
    run_params+=("$command_arg")
    display_command+=("${command_arg}")
  done
fi

ensure_stopped() {
  echo '+++ :warning: Signal received, stopping container gracefully'
  # docker stop "${container_name}" || true
  compose_cleanup ${run_service}
  echo '~~~ Last log lines that may be missing above (if container was not already removed)'
  docker logs "${container_name}" || true
  exit $1
}

trap 'ensure_stopped "$?"' SIGINT SIGTERM SIGQUIT


# Disable -e to prevent cancelling step if the command fails for whatever reason
set +e
exitcode=0

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

echo "${group_type} :docker: Running ${display_command[*]:-} in service $run_service"
run_docker_compose "${run_params[@]}"

exitcode=$?
if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode, run params:"
  echo "${run_params[@]}"
fi
# Restore -e as an option.
set -e

if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
  if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" != "false" ]] ; then
    print_failed_container_information

    upload_container_logs "$run_service"
  fi
fi

return "$exitcode"