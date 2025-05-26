#!/bin/bash
set -ueo pipefail

push_retries="$(plugin_read_config PUSH_RETRIES "0")"

if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_LOGS:-false}" = "true" ]]; then
  group_type="---"
else
  group_type="+++"
fi

# Targets for pushing come in a variety of forms:

# service <- just a service name
# service:image <- a service name and a specific image name to use
# service:image:tag <- a service name and a specific image and tag to use

# A push figures out the source image from either:
# 1. An image declaration in the docker-compose config for that service
# 2. The default projectname_service image format that docker-compose uses

pulled_services=("")
build_services=("")
push_command=(push)
pull_command=(pull)

if [ "$(plugin_read_config QUIET_PUSH 'false')" == "true" ]; then
  push_command+=("--quiet")
fi

if [ "$(plugin_read_config QUIET_PULL "false")" == "true" ] ; then
  pull_command+=("--quiet")
fi

if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD; then
  build_services=("${result[@]}")
fi

prebuilt_image_namespace="$(plugin_read_config PREBUILT_IMAGE_NAMESPACE 'docker-compose-plugin-')"

# Then we figure out what to push, and where
for line in $(plugin_read_list PUSH) ; do
  if [[ "$(plugin_read_config EXPAND_PUSH_VARS 'false')" == "true" ]]; then
    allowlist="$(plugin_read_config EXPAND_PUSH_VARS_ALLOWLIST '__UNSET__')"
    echo "allowlist=${allowlist}"
    if [[ "$allowlist" == "__UNSET__" ]]; then
      push_target="$(expand_var "$line")"
    else
      push_target="$(expand_var "$line" "$allowlist")"
    fi
  else
    push_target="$line"
  fi
  echo "pushtarget=${push_target}"
  IFS=':' read -r -a tokens <<< "$push_target"
  service_name=${tokens[0]}
  service_image="$(compose_image_for_service "$service_name")"

  if [ -n "${service_image}" ]; then # service has an image
    echo "~~~ :docker: Service has an image configuration: ${service_image}"
  elif in_array "${service_name}" "${build_services[@]}"; then
    echo "~~~ :docker: Service was built in this step, using that image"
    service_image="$(default_compose_image_for_service "${service_name}")"
  elif prebuilt_image="$(get_prebuilt_image "$prebuilt_image_namespace" "$service_name")"; then
    echo "~~~ :docker: Using pre-built image ${prebuilt_image}"

    # Only pull it down once
    if ! in_array "${service_name}" "${pulled_services[@]}" ; then
      echo "~~~ :docker: Pulling pre-built service ${service_name}" >&2;
      retry "$push_retries" plugin_prompt_and_run docker "${pull_command[@]}" "$prebuilt_image"
      pulled_services+=("${service_name}")
    fi

    service_image="${prebuilt_image}"
  else
    echo "+++ 🚨 No prebuilt-image nor built image found for service to push"
    exit 1
  fi

  if ! docker_image_exists "${service_image}"; then
    echo "+++ 🚨 Could not find image for service to push: ${service_image}"
    echo 'If you are using Docker Compose CLI v1, please ensure it is not a wrapper for v2'
    exit 1
  fi

  # push: "service-name"
  if [[ ${#tokens[@]} -eq 1 ]] ; then
    echo "${group_type} :docker: Pushing images for ${service_name}" >&2;
    retry "$push_retries" run_docker_compose "${push_command[@]}" "${service_name}"
    set_prebuilt_image "${prebuilt_image_namespace}" "${service_name}" "${service_image}"
    target_image="${service_image}" # necessary for build-alias
  # push: "service-name:repo:tag"
  else
    target_image="$(IFS=:; echo "${tokens[*]:1}")"
    echo "${group_type} :docker: Pushing image $target_image" >&2;
    plugin_prompt_and_run docker tag "$service_image" "$target_image"
    retry "$push_retries" plugin_prompt_and_run docker "${push_command[@]}" "$target_image"
    set_prebuilt_image "${prebuilt_image_namespace}" "${service_name}" "${target_image}"
  fi
done

# single image build
for service_alias in $(plugin_read_list BUILD_ALIAS) ; do
  if [ -z "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH:-}" ]; then
    echo "+++ 🚨 You can not use build-alias if you are not pushing a single service"
    exit 1
  fi

  set_prebuilt_image "${prebuilt_image_namespace}" "$service_alias" "${target_image}"
done
