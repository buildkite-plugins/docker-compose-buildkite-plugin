#!/bin/bash
set -ueo pipefail

prebuilt_images=( $(get_prebuilt_images_from_metadata) )

# Find any prebuilt images and pull them down
if [[ ${#prebuilt_images[@]} -gt 0 ]] ; then
  prebuilt_services=( $(get_services_from_map "${prebuilt_images[@]}") )

  echo "~~~ :docker: Pulling pre-built services ${prebuilt_services[*]}" >&2;
  for service in "${prebuilt_services[@]}" ; do
    if prebuilt_image=$(get_prebuilt_image "$service" "${prebuilt_images[@]}") ; then
      plugin_prompt_and_run docker pull "$prebuilt_image"
    fi
  done
fi

# Targets for pushing come in a variety of forms:

# service <- just a service name
# service:image <- a service name and a specific image name to use
# service:image:tag <- a service name and a specific image and tag to use

# A push figures out the source image from either:
# 1. An image declaration in the docker-compose config for that service
# 2. The default projectname_service image format that docker-compose uses

# Then we figure out what to push, and where
for line in $(plugin_read_list PUSH) ; do
  IFS=':' read -a tokens <<< "$line"
  service=${tokens[0]}
  service_image=$(compose_image_for_service "$service")
  prebuilt_image=

  if [[ ${#prebuilt_images[@]} -gt 0 ]] && prebuilt_image=$(get_prebuilt_image "$service" "${prebuilt_images[@]}") ; then
    echo "~~~ :docker: Tagging prebuilt image ${prebuilt_image} as ${service_image}" >&2;
    plugin_prompt_and_run docker tag "$prebuilt_image" "$service_image"
  elif ! docker_image_exists "${service_image}" ; then
    echo "~~~ :docker: Building ${service}" >&2;
    run_docker_compose build "$service"
  fi

  if [[ ${#tokens[@]} -eq 1 ]] ; then
    echo "~~~ :docker: Pushing images for $service" >&2;
    run_docker_compose push "$service"
  else
    target_image="$(IFS=:; echo "${tokens[*]:1}")"
    echo "~~~ :docker: Pushing image $target_image" >&2;
    plugin_prompt_and_run docker tag "$service_image" "$target_image"
    plugin_prompt_and_run docker push "$target_image"
  fi
done
