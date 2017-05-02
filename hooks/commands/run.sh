#!/bin/bash
set -ueo pipefail

service_name="$(plugin_read_config RUN)"
override_file="docker-compose.buildkite-${BUILDKITE_BUILD_NUMBER}-override.yml"

cleanup() {
  echo "~~~ :docker: Cleaning up after docker-compose" >&2
  compose_cleanup
}

# clean up docker containers on EXIT
if [[ "$(plugin_read_config CLEANUP "true")" == "true" ]] ; then
  trap cleanup EXIT
fi

test -f "$override_file" && rm "$override_file"

built_images=( $(get_prebuilt_images_from_metadata) )

echo "~~~ :docker: Found $((${#built_images[@]}/2)) pre-built services"

if [[ ${#built_images[@]} -gt 0 ]] ; then
  echo "~~~ :docker: Creating a modified docker-compose config for pre-built images" >&2;
  build_image_override_file "${built_images[@]}" | tee "$override_file"
  built_services=( $(get_services_from_map "${built_images[@]}") )

  echo "~~~ :docker: Pulling pre-built services ${built_services[*]}"
  run_docker_compose -f "$override_file" pull "${built_services[@]}"
fi

echo "+++ :docker: Running command in Docker Compose service: $service_name" >&2;
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