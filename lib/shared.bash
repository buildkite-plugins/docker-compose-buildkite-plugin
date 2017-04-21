
# Show a prompt for a command
function plugin_prompt {
  # Output "$" prefix in a pleasant grey...
  echo -ne "\033[90m$\033[0m"

  # ...each positional parameter with spaces and correct escaping for copy/pasting...
  printf " %q" "$@"

  # ...and a trailing newline.
  echo
}

# Shows the command being run, and runs it
function plugin_prompt_and_run {
  plugin_prompt "$@"
  "$@"
}

# Shows the command about to be run, and exits if it fails
function plugin_prompt_and_must_run {
  plugin_prompt_and_run "$@" || exit $?
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

# Runs the docker-compose command, scoped to the project, with the given arguments
function run_docker_compose() {
  local command=(docker-compose)

  for file in $(docker_compose_config_files) ; do
    command+=(-f "$file")
  done

  command+=(-p "$(docker_compose_project_name)")

  if [[ -z "${HIDE_PROMPT:-}" ]] ; then
    plugin_prompt_and_run "${command[@]}" "$@"
  else
    "${command[@]}" "$@"
  fi
}

function build_meta_data_image_tag_key() {
  echo "docker-compose-plugin-built-image-tag-$1"
}
