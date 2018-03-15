#!/bin/bash

readonly META_IMAGE_TAG=built-image-tag-

# Read agent metadata for the plugin
function plugin_get_metadata() {
  local key="docker-compose-plugin-$1"
  plugin_prompt buildkite-agent meta-data get "$key"
  buildkite-agent meta-data get "$key" || (
    echo "~~~ Failed to get metdata $key (exit $?)" >&2
    return 1
  )
}

# Write agent metadata for the plugin
function plugin_set_metadata() {
  local key="docker-compose-plugin-$1"
  local value="$2"
  plugin_prompt_and_must_run buildkite-agent meta-data set "$key" "$value"
}

function prebuilt_image_meta_data_key() {
  local service="$1"
  echo "${META_IMAGE_TAG}${service}"
}

# Sets a prebuilt image for a service name
function set_prebuilt_image() {
  local service="$1"
  local image="$2"
  plugin_set_metadata "$(prebuilt_image_meta_data_key "$service")" "$image"
}

# Gets a prebuilt image for a service name
function get_prebuilt_image() {
  local service="$1"
  plugin_get_metadata "$(prebuilt_image_meta_data_key "$service")"
}