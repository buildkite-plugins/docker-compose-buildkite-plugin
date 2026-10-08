#!/bin/bash

# Show a prompt for a command
function plugin_prompt() {
  if [[ -z "${HIDE_PROMPT:-}" ]] ; then
    echo -ne '\033[90m$\033[0m' >&"${PLUGIN_PROMPT_FD:-2}"
    for arg in "${@}" ; do
      if [[ $arg =~ [[:space:]] ]] ; then
        echo -n " '$arg'" >&"${PLUGIN_PROMPT_FD:-2}"
      else
        echo -n " $arg" >&"${PLUGIN_PROMPT_FD:-2}"
      fi
    done
    echo >&"${PLUGIN_PROMPT_FD:-2}"
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

# Runs a command with a wall-clock deadline, killing its entire process group if it
# does not finish in time. Uses a subshell with job control so each background job
# gets its own process group, ensuring descendants cannot outlive the deadline.
function run_with_deadline() (
     local seconds="$1"; shift
     local term_after=$((seconds > 1 ? seconds - 1 : 0))

     set -m
     "$@" &
     local cmd_pid=$!

     (
       sleep "$term_after"
       kill -TERM -- "-$cmd_pid" 2>/dev/null || exit 0
       sleep "$((seconds - term_after))"
       kill -KILL -- "-$cmd_pid" 2>/dev/null || true
     ) &
     local watcher_pid=$!

     wait "$cmd_pid" 2>/dev/null
     local status=$?

     if kill -0 -- "-$cmd_pid" 2>/dev/null; then
       wait "$watcher_pid" 2>/dev/null || true
     else
       kill -TERM -- "-$watcher_pid" 2>/dev/null || true
       wait "$watcher_pid" 2>/dev/null || true
     fi

     return "$status"
   )

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

# Reads either a value, a list, or a map from plugin config
# For map format (YAML object), outputs KEY=value pairs
# Additional arguments are sibling config key suffixes to exclude from map scanning
function plugin_read_list_or_map() {
  local config_key="$1"
  shift
  local prefix="BUILDKITE_PLUGIN_DOCKER_COMPOSE_${config_key}"
  local list_param="${prefix}_0"

  if [[ -n "${!list_param:-}" ]] || [[ -n "${!prefix:-}" ]]; then
    prefix_read_list "$prefix"
  else
    local scan_prefix="${prefix}_"
    local key
    while IFS= read -r varname ; do
      key="${varname#"${scan_prefix}"}"
      if ! in_array "${key}" "$@"; then
        echo "${key}=${!varname}"
      fi
    done < <(compgen -v "${scan_prefix}" | sort)
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

function plugin_config_exists() {
  local var="BUILDKITE_PLUGIN_DOCKER_COMPOSE_${1}"

  # Check if the variable is set
  [ "${!var+is_set}" != "" ]
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

  # If COMPOSE_PATH_SEPARATOR is not set, use the default separator
  if is_windows ; then
    DEFAULT_SEPARATOR=";"
  else
    DEFAULT_SEPARATOR=":"
  fi
  SEPARATOR="${COMPOSE_PATH_SEPARATOR:-$DEFAULT_SEPARATOR}"

  # Process any (deprecated) colon delimited config paths
  for value in "${config_files[@]}" ; do
    echo "$value" | tr "${SEPARATOR}" '\n'
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

# Checks that a specific version of docker-compose supports cache_from and cache_to
function docker_compose_supports_cache() {
  local version="$1"
  if [[ "$version" == 1* || "$version" =~ ^(2|3)(\.[01])?$ ]] ; then
    echo "Unsupported Docker Compose config file version: $version"
    echo "The 'cache_from' option can only be used with Compose file versions 2.2 or 3.2 and above."
    echo "For more information on Docker Compose configuration file versions, see:"
    echo "https://docs.docker.com/compose/compose-file/compose-versioning/#versioning"
    exit 1
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

    # load cache_to array
    cache_to_amt="${1:-0}"
    [[ -n "${1:-}" ]] && shift; # remove the value if not empty
    if [[ "${cache_to_amt}" -gt 0 ]]; then
      cache_to=()
      for _ in $(seq 1 "$cache_to_amt"); do
        cache_to+=( "$1" ); shift
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

    if [[ -z "$image_name" ]] && [[ -z "$target" ]] && [[ "$cache_from_amt" -eq 0 ]] && [[ "$cache_to_amt" -eq 0 ]] && [[ "$labels_amt" -eq 0 ]]; then
      # should not print out an empty service
      continue
    fi

    printf "  %s:\\n" "$service_name"

    if [[ -n "$image_name" ]]; then
      printf "    image: %s\\n" "$image_name"
    fi

    if [[ "$cache_from_amt" -gt 0 ]] || [[ "$cache_to_amt" -gt 0 ]] || [[ -n "$target" ]] || [[ "$labels_amt" -gt 0 ]]; then
      printf "    build:\\n"
    fi

    if [[ -n "$target" ]]; then
      printf "      target: %s\\n" "$target"
    fi

    if [[ "$cache_from_amt" -gt 0 ]] ; then
      docker_compose_supports_cache "$version"

      printf "      cache_from:\\n"
      for cache_from_i in "${cache_from[@]}"; do
        printf "        - %s\\n" "${cache_from_i}"
      done
    fi

    if [[ "$cache_to_amt" -gt 0 ]] ; then
      docker_compose_supports_cache "$version"

      printf "      cache_to:\\n"
      for cache_to_i in "${cache_to[@]}"; do
        printf "        - %s\\n" "${cache_to_i}"
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
    command+=(--ansi never)
  fi

  # Enable compatibility mode for v3 files
  if [[ "$(plugin_read_config COMPATIBILITY "false")" == "true" ]]; then
    command+=(--compatibility)
  fi

  if [[ -n "$(plugin_read_config PROGRESS)" ]]; then
    command+=(--progress "$(plugin_read_config PROGRESS)")
  fi

  for file in $(docker_compose_config_files) ; do
    command+=(-f "$file")
  done

  command+=(-p "$(docker_compose_project_name)")

  local disable_otel_config
  disable_otel_config="$(plugin_read_config DISABLE_HOST_OTEL_TRACING "false")"

  if [[ "$disable_otel_config" == "true" ]]; then
    # Disable docker-compose OTEL tracing by clearing environment variables
    # builkite-agent spans will still be created, but this will elminate docker-compose cli/run etc spans
    (
      unset TRACEPARENT
      unset TRACESTATE
      unset OTEL_EXPORTER_OTLP_ENDPOINT
      unset OTEL_EXPORTER_OTLP_HEADERS
      unset OTEL_EXPORTER_OTLP_PROTOCOL
      unset OTEL_SERVICE_NAME

      plugin_prompt_and_run "${command[@]}" "$@"
    )
  else
    plugin_prompt_and_run "${command[@]}" "$@"
  fi
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

function json_escape {
  local value="$1"
  value="$(printf '%s' "$value" | LC_ALL=C tr -d '\000-\010\013\014\016-\037')"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\r'/\\r}
  value=${value//$'\n'/\\n}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

# Runs a command and also saves its stderr to a file. Output and exit status
# are unchanged. Without a file, the command runs normally.
function run_copying_stderr {
  local stderr_file="$1"; shift
  if [[ -z "$stderr_file" ]]; then
    "$@"
    return
  fi
  { "$@" 2>&1 1>&3 3>&- | tee "$stderr_file" >&2 3>&-; return "${PIPESTATUS[0]}"; } 3>&1
}

# Prints a temporary file path for a stderr copy, or nothing if error capture
# is unavailable or a file can't be created.
function capture_stderr_file {
  [[ "${BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR:-}" == "true" ]] || return 0
  [[ -n "${BUILDKITE_AGENT_JOB_API_SOCKET:-}" && -n "${BUILDKITE_AGENT_JOB_API_TOKEN:-}" ]] || return 0
  mktemp 2>/dev/null || true
}

function stderr_is_terminal {
  [[ -t 2 ]]
}

# Runs Docker Compose and also saves its stderr to a file. The command line
# shown before it is left out of the file, as it can include build args.
function run_docker_compose_copying_stderr {
  local stderr_file="$1"; shift
  if [[ -z "$stderr_file" ]]; then
    run_docker_compose "$@"
    return
  fi
  # Compose shows plain progress when stderr isn't a terminal. Keep the
  # interactive display, unless progress or plain output is configured.
  if stderr_is_terminal && [[ -z "$(plugin_read_config PROGRESS)" && -z "${COMPOSE_PROGRESS:-}" \
    && "$(plugin_read_config ANSI "true")" != "false" && "${COMPOSE_ANSI:-}" != "never" \
    && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
    local -x COMPOSE_PROGRESS=tty
  fi
  PLUGIN_PROMPT_FD=4 run_copying_stderr "$stderr_file" run_docker_compose "$@" 4>&2
}

# Prints the last non-blank line of a stderr file, which is usually the error,
# without terminal escape codes. Prints nothing if the line is longer than
# max_chars, because cutting it could leave part of a secret that can no
# longer be redacted.
function stderr_error_line {
  local stderr_file="$1" max_chars="$2" line
  [[ -s "$stderr_file" ]] || return 0
  line=$(tr '\r' '\n' <"$stderr_file" \
    | sed -e $'s/\x1b\\[[0-?]*[ -/]*[@-~]//g' \
      -e $'s/\x1b][^\x07\x1b]*\x07//g' -e $'s/\x1b][^\x07\x1b]*\x1b\\\\//g' \
      -e $'s/\x1b[()][0-9A-Za-z]//g' \
      -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr -d '\000-\010\013-\037\177' \
    | grep -v '^$' \
    | tail -n 1) || true
  if (( $(printf '%s' "$line" | wc -m) <= max_chars )); then
    printf '%s' "$line"
  fi
}

# The agent accepts up to 1,500 characters. This leaves room for [REDACTED]
# replacements.
CAPTURED_ERROR_MESSAGE_MAX_CHARS=1000

# Captures a job error. If stderr_file is given, Docker Compose's error is added to
# the message. Reporting failures are ignored.
function capture_compose_error {
  local error_code="$1" message="$2" stderr_file="${3:-}" detail
  [[ "${BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR:-}" == "true" ]] || return 0
  [[ -n "${BUILDKITE_AGENT_JOB_API_SOCKET:-}" && -n "${BUILDKITE_AGENT_JOB_API_TOKEN:-}" ]] || return 0

  if [[ -n "$stderr_file" ]]; then
    detail=$(stderr_error_line "$stderr_file" "$((CAPTURED_ERROR_MESSAGE_MAX_CHARS - ${#message} - 2))")
    if [[ -n "$detail" ]]; then
      message+=": $detail"
    fi
  fi
  buildkite-agent job capture-error "$error_code" --message "$message" >/dev/null 2>&1 || true
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

function builder_instance_exists() {
    local builder_name="$1"

    # Check if the specified builder exists by suppressing output and checking the exit status
    if docker buildx inspect "${builder_name}" >/dev/null 2>&1; then
        return 0 # Builder exists
    else
        return 1 # Builder does not exist
    fi
}
