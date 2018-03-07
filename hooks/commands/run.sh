#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

service_name="$(plugin_read_config RUN)"
container_name="$(docker_compose_project_name)_${service_name}_build_${BUILDKITE_BUILD_NUMBER}"
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

# We support pulling all images, in case they have been pulled on the agent machine already in
# an earlier build, and need to be updated
if [[ "$(plugin_read_config PULL_ALL "false")" == "true" ]] ; then
    echo "~~~ :docker: Pulling all images"
    retry "$pull_retries" run_docker_compose pull --parallel
fi

test -f "$override_file" && rm "$override_file"

# We only look for a prebuilt image for the serice being run. This means that
# any other services that are dependencies that need to be built will be built
# on-demand in this step, even if they were prebuilt in an earlier step.

if prebuilt_image=$(get_prebuilt_image "$service_name") ; then
  echo "~~~ :docker: Found a pre-built image for $service_name"
  build_image_override_file "${service_name}" "${prebuilt_image}" "" | tee "$override_file"

  echo "~~~ :docker: Pulling pre-built services $service_name"
  retry "$pull_retries" run_docker_compose -f "$override_file" pull "$service_name"
fi

# Now we build up the run command that will be called
run_params=()

if [[ -f "$override_file" ]]; then
  run_params+=(-f "$override_file")
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

run_params+=("$service_name")

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

  if [[ -f "$override_file" ]]; then
    echo "+++ :docker: Running command in Docker Compose service: $service_name" >&2
    eval "run_docker_compose \${run_params[@]} $BUILDKITE_COMMAND"
  else
    echo "~~~ :docker: Building Docker Compose Service: $service_name" >&2
    run_docker_compose build --pull "$service_name"

    echo "+++ :docker: Running command in Docker Compose service: $service_name" >&2
    eval "run_docker_compose \${run_params[@]} $BUILDKITE_COMMAND"
  fi
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
