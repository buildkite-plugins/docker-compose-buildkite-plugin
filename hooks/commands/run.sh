#!/bin/bash

run_service_name="$(plugin_read_config RUN)"
override_file="docker-compose.buildkite-${run_service_name}-override.yml"

trap compose_force_cleanup EXIT

try_image_restore_from_docker_repository

echo "+++ :docker: Running command in Docker Compose service: $run_service_name"

# $BUILDKITE_COMMAND needs to be unquoted because:
#   docker-compose run "app" "go test"
# does not work whereas the follow does:
#   docker-compose run "app" go test

if [[ -f "$override_file" ]]; then
  run_docker_compose -f "$override_file" run "$run_service_name" $BUILDKITE_COMMAND
else
  run_docker_compose run "$run_service_name" $BUILDKITE_COMMAND
fi

exitcode=$?

if [[ $exitcode -ne 0 ]] ; then
  echo "^^^ +++"
  echo "+++ :warning: Failed to run command, exited with $exitcode"
fi

echo "~~~ Checking linked containers"
check_linked_containers "docker-compose-logs" "$exitcode"

echo "~~~ Uploading container logs as artifacts"
buildkite-agent artifact upload "docker-compose-logs/*.log"

exit $exitcode