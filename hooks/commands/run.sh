#!/bin/bash
set -eu

service_name="$(plugin_read_config RUN)"
override_file="docker-compose.buildkite-${service_name}-override.yml"

cleanup() {
  echo "~~~ :docker: Cleaning up after docker-compose"
  compose_cleanup
}

# clean up docker containers on EXIT
trap cleanup EXIT

test -f "$override_file" && rm "$override_file"

if build_image=$(get_prebuilt_image_from_metadata "$service_name") ; then
  echo "~~~ :docker: Creating a modified Docker Compose config"
  build_image_override_file "$service_name" "$build_image" \
    | tee "$override_file"

  echo "~~~ :docker: Pulling down latest images"
  run_docker_compose -f "$override_file" pull "$service_name"
fi

echo "+++ :docker: Running command in Docker Compose service: $service_name"
set +e

# $BUILDKITE_COMMAND needs to be unquoted because:
#   docker-compose run "app" "go test"
# does not work whereas the follow does:
#   docker-compose run "app" go test

if [[ -f "$override_file" ]]; then
  run_docker_compose -f "$override_file" run "$service_name" $BUILDKITE_COMMAND
else
  run_docker_compose run "$service_name" $BUILDKITE_COMMAND
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