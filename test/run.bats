#!/usr/bin/env bats

load '../lib/shared'

docker-compose(){
  echo "docker-compose" "$@"
}
docker(){
  echo "docker" "$@"
}

@test "Run command fails without BUILDKITE_COMMAND" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=1
  export BUILDKITE_JOB_ID=123
  export HIDE_PROMPT=1
  run "$PWD/hooks/command"
  echo $output
  [ "$status" -eq 1 ]
  [ "$output" == "No command to run. Did you provide a 'command' for this step?" ]
}
