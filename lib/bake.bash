#!/bin/bash

BAKE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# compose_image_for_service lives in push.bash; source it so the pushed image can
# be recorded in metadata for later run/push steps, exactly like the push command.
# shellcheck source=lib/push.bash
. "$BAKE_LIB_DIR/push.bash"

# Builds the given services with `docker buildx bake` and pushes them straight to
# the registry, instead of the regular `docker compose build` (which loads the
# built image into the local Docker daemon first).
#
# With the `docker-container` or `remote` build drivers the built image lives in
# BuildKit's own store, so `docker compose build` has to export it as a tarball
# and import it into the daemon before it can be pushed. For large images (for
# example Windows containers, whose base layers are several GB) that load
# dominates the step even on a full cache hit. `bake --push` uses BuildKit's
# registry exporter, so the image goes from BuildKit to the registry directly and
# the daemon is never involved.
#
# The generated override file and the Compose config files carry the image tags,
# cache_from/cache_to, target and labels, and bake reads them through `--file`,
# so those options apply unchanged.
#
# Usage: build_with_bake <override_file> <group_type> <service>...
# `override_file` and `group_type` are computed by commands/build.sh and passed
# in so both build paths share the same values.
function build_with_bake() {
  local override_file="$1"
  local group_type="$2"
  shift 2
  local services=("$@")

  local bake_params=(buildx bake)

  local file
  for file in $(docker_compose_config_files) ; do
    bake_params+=(--file "$file")
  done

  if [[ -f "${override_file}" ]]; then
    bake_params+=(--file "${override_file}")
  fi

  if [[ -n "$(plugin_read_config BUILDER_NAME "")" ]] && [[ "$(plugin_read_config BUILDER_USE "false")" == "true" ]]; then
    bake_params+=(--builder "$(plugin_read_config BUILDER_NAME "")")
  fi

  if [[ ! "$(plugin_read_config SKIP_PULL "false")" == "true" ]] ; then
    bake_params+=(--pull)
  fi

  if [[ "$(plugin_read_config NO_CACHE "false")" == "true" ]] ; then
    bake_params+=(--no-cache)
  fi

  # bake writes to the daemon by default; push straight to the registry so the
  # image is never round-tripped through a local daemon load.
  bake_params+=(--push)

  if [[ "$(plugin_read_config BUILDKIT_INLINE_CACHE "false")" == "true" ]] ; then
    bake_params+=(--set "*.args.BUILDKIT_INLINE_CACHE=1")
  fi

  if [[ "$(plugin_read_config SSH "false")" != "false" ]] ; then
    local ssh_context
    ssh_context="$(plugin_read_config SSH)"
    if [[ "${ssh_context}" == "true" ]]; then
      ssh_context='default'
    fi
    bake_params+=(--set "*.ssh=${ssh_context}")
  fi

  local arg
  while read -r arg ; do
    [[ -n "${arg:-}" ]] && bake_params+=(--set "*.args.${arg}")
  done <<< "$(plugin_read_list ARGS)"

  bake_params+=("${services[@]}")

  echo "${group_type} :docker: Building and pushing services with bake: ${services[*]}"
  plugin_prompt_and_must_run docker "${bake_params[@]}"

  # Record the pushed image for each service so later run/push steps pull it
  # instead of falling back to a rebuild (mirrors the push command's behaviour).
  #
  # The resolved Compose config is fetched once and reused for every service,
  # rather than running `docker compose config` per service.
  if [[ "$(plugin_read_config PUSH_METADATA "true")" == "true" ]] ; then
    local prebuilt_image_namespace compose_config service image
    prebuilt_image_namespace="$(plugin_read_config PREBUILT_IMAGE_NAMESPACE 'docker-compose-plugin-')"
    compose_config="$(run_docker_compose config)"
    for service in "${services[@]}" ; do
      image="$(compose_image_for_service "$service" "$compose_config")"
      if [[ -n "$image" ]] ; then
        set_prebuilt_image "${prebuilt_image_namespace}" "${service}" "${image}"
      fi
    done
  fi
}
