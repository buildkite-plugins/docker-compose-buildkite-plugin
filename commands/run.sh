#!/bin/bash
set -uo pipefail

. "$DIR/../commands/pull.sh"
. "$DIR/../commands/run_params_generator.sh"
. "$DIR/../commands/cmd_to_run_generator.sh"

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

pulled_status=0
pull "$run_service" || pulled_status=$?
echo "pulled_status: $pulled_status"

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

# We set a predictable container name so we can find it and inspect it later on
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

  exit $dependency_exitcode
fi


# Assemble the shell and command arguments into the docker arguments
display_command=()
commands=()
generate_cmd "commands" "display_command"

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

echo "${group_type} :docker: Running ${display_command[*]:-} in service $run_service"
echo "commands is: ${commands[@]}"
# printf -v cmd_lit ' "%s" ' "${commands[@]}"
cmd_lit=( "${run_params[@]}" "${commands[@]}" )
# cmd_lit=( "${run_params[@]}" "echo hello world, I'm starting here; sleep 10000" )
echo "PID is: $BASHPID"

exitcode=0
(
  echo "docker compose being called. PID is: $BASHPID"
  run_docker_compose "${cmd_lit[@]}" || exitcode=$?
)


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

exit "$exitcode"