#!/bin/bash

check_required_args() {
  if [[ -z "${BUILDKITE_COMMAND:-}" ]]; then
    echo "No command to run. Did you provide a 'command' for this step?"
    exit 1
  fi
}

create_compose_script() {
  # Generate a different script depending on whether or not it's a script to
  # execute
  if [[ -f "$1" ]]; then
    # Make sure the script they're trying to execute has chmod +x. We can't do
    # this inside the script we generate because it fails within Docker:
    # https://github.com/docker/docker/issues/9547
    buildkite-run "chmod +x \"$1\""
    echo -e '#!/bin/bash'"\n./\"$1\"" > "$2"
  else
    echo -e '#!/bin/bash'"\n$1" > "$2"
  fi

  if [[ ! -z "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_DEBUG:-}" ]]; then
    echo "~~~ DEBUG: Contents of build script $2"
    buildkite-run "cat $2"
  fi

  # Ensure the temporary build script can be executed
  chmod +x "$2"
}

compose_cleanup() {
  echo "~~~ Cleaning up Docker containers"
  run_docker_compose "kill" || true
  run_docker_compose "rm --force -v" || true
  # The adhoc run container isn't cleaned up by compose, so we have to do it ourselves
  buildkite-run "docker rm -f -v ${COMPOSE_CONTAINER_NAME}_run_1 || true"
}

check_required_args

trap compose_cleanup EXIT

create_compose_script "$BUILDKITE_COMMAND" "buildkite-script-$BUILDKITE_JOB_ID"

echo "~~~ Building Docker Compose service images"

# echo "Checking for pre-built images..."

echo "None found. Building..."

run_docker_compose build

echo "~~~ Running command in Docker Compose service: $BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN"

run_docker_compose "\"./buildkite-script-$BUILDKITE_JOB_ID\""
