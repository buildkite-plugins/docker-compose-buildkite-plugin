#!/bin/bash

# Show a prompt for a command
function plugin_prompt() {
  if [[ -z "${HIDE_PROMPT:-}" ]] ; then
    echo -ne "\033[90m$\033[0m" >&2
    printf " %q" "$@" >&2
    echo >&2
  fi
}

# Shows the command being run, and runs it
function plugin_prompt_and_run() {
  plugin_prompt "$@"
  "$@"
}

# Shows the command about to be run, and exits if it fails
function plugin_prompt_and_must_run() {
  plugin_prompt_and_run "$@" || exit $?
}

# Shorthand for reading env config
function plugin_read_config() {
  local var="BUILDKITE_PLUGIN_DOCKER_COMPOSE_${1}"
  local default="${2:-}"
  echo "${!var:-$default}"
}

# Reads either a value or a list from plugin config
function plugin_read_list() {
  local prefix="BUILDKITE_PLUGIN_DOCKER_COMPOSE_$1"
  local parameter="${prefix}_0"

  if [[ -n "${!parameter:-}" ]]; then
    local i=0
    local parameter="${prefix}_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      echo "${!parameter}"
      i=$((i+1))
      parameter="${prefix}_${i}"
    done
  elif [[ -n "${!prefix:-}" ]]; then
    echo "${!prefix}"
  fi
}

# Returns the name of the docker compose project for this build
function docker_compose_project_name() {
  # No dashes or underscores because docker-compose will remove them anyways
  echo "buildkite${BUILDKITE_JOB_ID//-}"
}

# Returns the name of the docker compose container that corresponds to the
# given service
function docker_compose_container_name() {
  echo "$(docker_compose_project_name)_$1"
}

# Returns all docker compose config file names split by newlines
function docker_compose_config_files() {
  config_files=( $( plugin_read_list CONFIG ) )

  if [[ ${#config_files[@]} -eq 0 ]]  ; then
    echo "docker-compose.yml"
    return
  fi

  # Process any (deprecated) colon delimited config paths
  for value in "${config_files[@]}" ; do
    echo "$value" | tr ':' '\n'
  done
}

# Returns the first docker compose config file name
function docker_compose_config_file() {
  if ! config_files=( $(docker_compose_config_files) ) ; then
    echo "docker-compose.yml"
  fi

  echo "${config_files[0]}"
}

# Returns the version of the first docker compose config file
function docker_compose_config_version() {
  sed -n "s/version: ['\"]\(.*\)['\"]/\1/p" < "$(docker_compose_config_file)"
}

# Build an docker-compose file that overrides the image for a set of
# service and image pairs
function build_image_override_file() {
  build_image_override_file_with_version \
    "$(docker_compose_config_version)" "$@"
}

# Build an docker-compose file that overrides the image for a specific
# docker-compose version and set of service and image pairs
function build_image_override_file_with_version() {
  local version="$1"

  printf "version: '%s'\n" "$version"
  printf "services:\n"

  shift
  while test ${#} -gt 0 ; do
    printf "  %s:\n" "$1"
    printf "    image: %s\n" "$2"
    shift 2
  done
}

# Runs the docker-compose command, scoped to the project, with the given arguments
function run_docker_compose() {
  local command=(docker-compose)

  for file in $(docker_compose_config_files) ; do
    command+=(-f "$file")
  done

  command+=(-p "$(docker_compose_project_name)")

  plugin_prompt_and_run "${command[@]}" "$@"
}
