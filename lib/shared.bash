
# Show a prompt for a command
function plugin_prompt() {
  if [[ -z "${HIDE_PROMPT:-}" ]] ; then
    echo -ne "\033[90m$\033[0m"
    printf " %q" "$@"
    echo
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

# Read agent metadata for pre-built images
function plugin_get_build_image_metadata() {
  local service="$1"
  plugin_prompt_and_must_run \
    buildkite-agent meta-data get \
    "docker-compose-plugin-built-image-tag-${service}"
}

# Write agent metadata for pre-built images
function plugin_set_build_image_metadata() {
  local service="$1"
  local value="$2"
  plugin_prompt_and_must_run \
    buildkite-agent meta-data set \
    "docker-compose-plugin-built-image-tag-${service}" "$value"
}

# Returns the name of the docker compose project for this build
function docker_compose_project_name() {
  # No dashes or underscores because docker-compose will remove them anyways
  echo "buildkite${BUILDKITE_JOB_ID//-}"
}

# Returns the name of the docker compose container that corresponds to the given service
function docker_compose_container_name() {
  echo "$(docker_compose_project_name)_$1"
}

# Returns the first docker compose config file name
function docker_compose_config_files() {
  if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0:-}" ]]; then
    # Plugin config specified an array of config files
    local i=0
    local parameter="BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_${i}"
    while [[ -n "${!parameter:-}" ]]; do
      echo "${!parameter}"
      i=$((i+1))
      parameter="BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_${i}"
    done
  elif [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG:-}" ]]; then
    # Plugin config may be colon-separated files
    declare file
    declare -a files
    IFS=":" read -ra files <<< "$BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG"
    for file in "${files[@]}"; do
      echo "$file"
    done
  else
    # Use default docker compose location
    echo "docker-compose.yml"
  fi
}

# Returns the first docker compose config file name
function docker_compose_config_file() {
  docker_compose_config_files | head -n1
}

# Build an docker-compose file that overrides the image for a given service
function build_image_override_file() {
  local service="$1"
  local image="$2"

  printf "version: '2'\n"
  printf "services:\n"
  printf "  %s:\n" "$service"
  printf "    image: %s\n" "$image"
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
