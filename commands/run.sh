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

test -f "$override_file" && rm "$override_file"

pull "$run_service"
pulled_status=$?
echo "pulled_status: $pulled_status"

expand_headers_on_error() {
  echo "^^^ +++"
}
trap expand_headers_on_error ERR

if [[ ! -f "$override_file" ]] ; then
  echo "+++ 🚨 No pre-built image found from a previous 'build' step for this service and config file."

  if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_REQUIRE_PREBUILD:-}" =~ ^(true|on|1)$ ]]; then
    echo "The step specified that it was required"
    exit 1
  fi
else
  echo "~~~ :docker: Using pre-built image for $run_service"
fi

up_params=()
declare -a run_params
run_params+=("run" "--name" "$container_name")
generate_run_args "run_params" $pulled_status
echo "run_params after func: ${run_params[@]}"

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
  echo "^^^ +++"
  echo "+++ 🚨 Failed to start dependencies"

  if [[ -n "${BUILDKITE_AGENT_ACCESS_TOKEN:-}" ]] ; then
    print_failed_container_information

    upload_container_logs "$run_service"
  fi

  return $dependency_exitcode
fi


# Assemble the shell and command arguments into the docker arguments
display_command=()
commands=()

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
    commands+=("$arg")
  done
fi

# Set a default shell if one is needed
if [[ -z $shell_disabled ]] && [[ ${#commands[@]} -eq 0 ]] ; then
  if is_windows ; then
    commands=("CMD.EXE" "/c")
  # else
    # commands=("/bin/sh" "-e" "-c")
  fi
fi

if [[ ${#commands[@]} -gt 0 ]] ; then
  for shell_arg in "${commands[@]}" ; do
    display_command+=("$shell_arg")
  done
fi

# Show a helpful error message if string version of command is used
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND:-}" ]] ; then
  echo "🚨 The Docker Compose Plugin’s command configuration option must be an array."
  exit 1
fi

# Parse plugin command if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND ; then
  if [[ "${#result[@]}" -gt 0 ]] && [[ -n "${BUILDKITE_COMMAND}" ]] ; then
    echo "+++ Error: Can't use both a step level command and the command parameter of the plugin"
    exit 1
  elif [[ "${#result[@]}" -gt 0 ]] ; then
    echo "compose plugin command: ${result[@]}"
    for arg in "${result[@]}" ; do
      commands+=("$arg")
      display_command+=("$arg")
    done
  fi
fi
if [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  echo "buildkite command: ${BUILDKITE_COMMAND}"
  if [[ $(echo "$BUILDKITE_COMMAND" | wc -l) -gt 1 ]]; then
    # FIXME: This is easy to fix, just need to do at end

    # An array of commands in the step will be a single string with multiple lines
    # This breaks a lot of things here so we will print a warning for user to be aware
    echo "⚠️  Warning: The command received has multiple lines."
    echo "⚠️           The Docker Compose Plugin does not correctly support step-level array commands."
  fi
  commands+=("${BUILDKITE_COMMAND}")
  display_command+=("'${BUILDKITE_COMMAND}'")
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

exitcode=0

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

echo "${group_type} :docker: Running ${display_command[*]:-} in service $run_service"
echo "commands is: ${commands[@]}"
cmd_lit="[${commands[@]}]"
echo "cmd_lit is: ${cmd_lit}"
run_docker_compose "${run_params[@]}" "$cmd_lit"

exitcode=$?
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

return "$exitcode"