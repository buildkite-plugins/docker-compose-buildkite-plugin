#!/bin/bash

# Show a prompt for a command
function plugin_prompt() {
  if [[ -z "${HIDE_PROMPT:-}" ]] ; then
    echo -ne '\033[90m$\033[0m' >&2
    for arg in "${@}" ; do
      if [[ $arg =~ [[:space:]] ]] ; then
        echo -n " '$arg'" >&2
      else
        echo -n " $arg" >&2
      fi
    done
    echo >&2
  fi
}

# Shows the command being run, and runs it
function plugin_prompt_and_run() {
  local exit_code

  plugin_prompt "$@"
  "$@"
  exit_code=$?

  # Sometimes docker-compose pull leaves unfinished ansi codes
  echo

  return $exit_code
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
  prefix_read_list "BUILDKITE_PLUGIN_DOCKER_COMPOSE_$1"
}

# Reads either a value or a list from the given env prefix
function prefix_read_list() {
  local prefix="$1"
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

# Reads either a value or a list from plugin config into a global result array
# Returns success if values were read
function plugin_read_list_into_result() {
  local prefix="$1"
  local parameter="${prefix}_0"
  result=()

  if [[ -n "${!parameter:-}" ]]; then
    local i=0
    local parameter="${prefix}_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      result+=("${!parameter}")
      i=$((i+1))
      parameter="${prefix}_${i}"
    done
  elif [[ -n "${!prefix:-}" ]]; then
    result+=("${!prefix}")
  fi

  [[ ${#result[@]} -gt 0 ]] || return 1
}

# Returns the name of the docker compose project for this build
function docker_compose_project_name() {
  # No dashes or underscores because docker-compose will remove them anyways
  echo "buildkite${BUILDKITE_JOB_ID//-}"
}

# Runs docker ps -a filtered by the current project name
function docker_ps_by_project() {
  docker ps -a \
    --filter "label=com.docker.compose.project=$(docker_compose_project_name)" \
    "${@}"
}

# Returns all docker compose config file names split by newlines
function docker_compose_config_files() {
  local -a config_files=()

  # Parse the list of config files into an array
  while read -r line ; do
    [[ -n "$line" ]] && config_files+=("$line")
  done <<< "$(plugin_read_list CONFIG)"

  # Use a default if there are no config files specified
  if [[ -z "${config_files[*]:-}" ]]  ; then
    echo "${COMPOSE_FILE:-docker-compose.yml}"
    return
  fi

  # Process any (deprecated) colon delimited config paths
  for value in "${config_files[@]}" ; do
    echo "$value" | tr ':' '\n'
  done
}

# Returns the version from the output of docker_compose_config
function docker_compose_config_version() {
  IFS=$'\n' read -r -a config <<< "$(docker_compose_config_files)"
  grep 'version' < "${config[0]}" | sort -r | awk '/^\s*version:/ { print $2; exit; }'  | sed "s/[\"']//g"
}

# Build an docker-compose file that overrides the image for a set of
# service and image pairs
function build_image_override_file() {
  build_image_override_file_with_version \
    "$(docker_compose_config_version)" "$@"
}

# Checks that a specific version of docker-compose supports cache_from
function docker_compose_supports_cache_from() {
  local version="$1"
  if [[ "$version" == 1* || "$version" =~ ^(2|3)(\.[01])?$ ]] ; then
    return 1
  fi
}

# Build an docker-compose file that overrides the image for a specific
# docker-compose version and set of [ service, image, num_cache_from, cache_from1, cache_from2, ... ] tuples
function build_image_override_file_with_version() {
  local version="$1"

  if [[ "$version" == 1* ]] ; then
    echo "The 'build' option can only be used with Compose file versions 2.0 and above."
    echo "For more information on Docker Compose configuration file versions, see:"
    echo "https://docs.docker.com/compose/compose-file/compose-versioning/#versioning"
    exit 1
  fi

  if [[ -n "$version" ]]; then
    printf "version: '%s'\\n" "$version"
  fi

  printf "services:\\n"

  shift
  while test ${#} -gt 0 ; do
    service_name=$1
    image_name=$2
    target=$3
    shift 3

    # load cache_from array
    cache_from_amt="${1:-0}"
    [[ -n "${1:-}" ]] && shift; # remove the value if not empty
    if [[ "${cache_from_amt}" -gt 0 ]]; then
      cache_from=()
      for _ in $(seq 1 "$cache_from_amt"); do
        cache_from+=( "$1" ); shift
      done
    fi

    # load labels array
    labels_amt="${1:-0}"
    [[ -n "${1:-}" ]] && shift; # remove the value if not empty
    if [[ "${labels_amt}" -gt 0 ]]; then
      labels=()
      for _ in $(seq 1 "$labels_amt"); do
        labels+=( "$1" ); shift
      done
    fi

    if [[ -z "$image_name" ]] && [[ -z "$target" ]] && [[ "$cache_from_amt" -eq 0 ]] && [[ "$labels_amt" -eq 0 ]]; then
      # should not print out an empty service
      continue
    fi

    printf "  %s:\\n" "$service_name"

    if [[ -n "$image_name" ]]; then
      printf "    image: %s\\n" "$image_name"
    fi

    if [[ "$cache_from_amt" -gt 0 ]] || [[ -n "$target" ]] || [[ "$labels_amt" -gt 0 ]]; then
      printf "    build:\\n"
    fi

    if [[ -n "$target" ]]; then
      printf "      target: %s\\n" "$target"
    fi

    if [[ "$cache_from_amt" -gt 0 ]] ; then
      if ! docker_compose_supports_cache_from "$version" ; then
        echo "Unsupported Docker Compose config file version: $version"
        echo "The 'cache_from' option can only be used with Compose file versions 2.2 or 3.2 and above."
        echo "For more information on Docker Compose configuration file versions, see:"
        echo "https://docs.docker.com/compose/compose-file/compose-versioning/#versioning"
        exit 1
      fi

      printf "      cache_from:\\n"
      for cache_from_i in "${cache_from[@]}"; do
        printf "        - %s\\n" "${cache_from_i}"
      done
    fi

    if [[ "$labels_amt" -gt 0 ]] ; then
      printf "      labels:\\n"
      for label in "${labels[@]}"; do
        printf "        - %s\\n" "${label}"
      done
    fi
  done
}

# Runs the docker-compose command, scoped to the project, with the given arguments
function run_docker_compose() {
  local command=(docker-compose)
  if [[ "$(plugin_read_config CLI_VERSION "2")" == "2" ]] ; then
    command=(docker compose)
  fi

  if [[ "$(plugin_read_config VERBOSE "false")" == "true" ]] ; then
    command+=(--verbose)
  fi

  if [[ "$(plugin_read_config ANSI "true")" == "false" ]] ; then
    command+=(--no-ansi)
  fi

  # Enable compatibility mode for v3 files
  if [[ "$(plugin_read_config COMPATIBILITY "false")" == "true" ]]; then
    command+=(--compatibility)
  fi

  for file in $(docker_compose_config_files) ; do
    command+=(-f "$file")
  done

  command+=(-p "$(docker_compose_project_name)")

  echo "running: ${command[@]}"

  plugin_prompt_and_run "${command[@]}" "$@"
}

function in_array() {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# retry <number-of-retries> <command>
function retry {
  local retries=$1; shift
  local attempts=1
  local status=0

  until "$@"; do
    status=$?
    echo "Exited with $status"
    if (( retries == "0" )); then
      return $status
    elif (( attempts == retries )); then
      echo "Failed $attempts retries"
      return $status
    else
      echo "Retrying $((retries - attempts)) more times..."
      attempts=$((attempts + 1))
      sleep $(((attempts - 2) * 2))
    fi
  done
}

function is_windows() {
  [[ "$OSTYPE" =~ ^(win|msys|cygwin) ]]
}

function is_macos() {
  [[ "$OSTYPE" =~ ^(darwin) ]]
}

function validate_tag {
  local tag=$1

  if [[ "$tag" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
    return 0
  else
    return 1
  fi
}
