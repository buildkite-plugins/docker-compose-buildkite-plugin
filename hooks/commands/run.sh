#!/bin/bash
set -ueo pipefail

# Run takes a service name, pulls down any pre-built image for that name
# and then runs docker-compose run a generated project name

service_name="$(plugin_read_config RUN)"
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

# We only look for a prebuilt image for the serice being run. This means that
# any other services that are dependencies that need to be built will be built
# on-demand in this step, even if they were prebuilt in an earlier step.

if prebuilt_image=$(get_prebuilt_image "$service_name") ; then
  echo "~~~ :docker: Found a pre-built image for $service_name"
  build_image_override_file "${service_name}" "${prebuilt_image}" | tee "$override_file"

  echo "~~~ :docker: Pulling pre-built services $service_name"
  retry "$pull_retries" run_docker_compose -f "$override_file" pull "$service_name"
fi

echo "+++ :docker: Running command in Docker Compose service: $service_name" >&2;
set +e

# $BUILDKITE_COMMAND needs to be unquoted because:
#   docker-compose run "app" "go test"
# does not work whereas the following does:
#   docker-compose run "app" go test

run_params="$(docker_compose_env_params)"

if [[ -f "$override_file" ]]; then
  run_docker_compose -f "$override_file" run $run_params "$service_name" $BUILDKITE_COMMAND
else
  run_docker_compose build --pull "$service_name"
  run_docker_compose run $run_params "$service_name" $BUILDKITE_COMMAND
fi

exitcode=$?

if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode"
else
  echo "~~~ :docker: Container exited normally"
fi

if [[ "$(plugin_read_config CHECK_LINKED_CONTAINERS "true")" == "true" ]] ; then
  echo "~~~ Checking linked containers"
  check_linked_containers "docker-compose-logs" "$exitcode"

  echo "~~~ Uploading container logs as artifacts"
  buildkite-agent artifact upload "docker-compose-logs/*.log"
fi

exit $exitcode
