#!/bin/bash
set -uo pipefail

function generate_run_args() {
	local -n params="$1"
	service_was_pulled=$2

	if [[ $service_was_pulled -eq 0 ]] ; then
		echo "~~~ :docker: Creating docker-compose override file for prebuilt services"
		params+=(-f "$override_file")
		up_params+=(-f "$override_file")
	fi

	if [[ "$(plugin_read_config RUN_LABELS "true")" =~ ^(true|on|1)$ ]]; then
		# Add useful labels to run container
		params+=(
			"--label" "com.buildkite.pipeline_name=${BUILDKITE_PIPELINE_NAME}"
			"--label" "com.buildkite.pipeline_slug=${BUILDKITE_PIPELINE_SLUG}"
			"--label" "com.buildkite.build_number=${BUILDKITE_BUILD_NUMBER}"
			"--label" "com.buildkite.job_id=${BUILDKITE_JOB_ID}"
			"--label" "com.buildkite.job_label=${BUILDKITE_LABEL}"
			"--label" "com.buildkite.step_key=${BUILDKITE_STEP_KEY}"
			"--label" "com.buildkite.agent_name=${BUILDKITE_AGENT_NAME}"
			"--label" "com.buildkite.agent_id=${BUILDKITE_AGENT_ID}"
		)
	fi

	# append env vars provided in ENV or ENVIRONMENT, these are newline delimited
	while IFS=$'\n' read -r env ; do
		[[ -n "${env:-}" ]] && params+=("-e" "${env}")
	done <<< "$(printf '%s\n%s' \
		"$(plugin_read_list ENV)" \
		"$(plugin_read_list ENVIRONMENT)")"

	# Propagate all environment variables into the container if requested
	if [[ "$(plugin_read_config PROPAGATE_ENVIRONMENT "false")" =~ ^(true|on|1)$ ]] ; then
		if [[ -n "${BUILDKITE_ENV_FILE:-}" ]] ; then
			# Read in the env file and convert to --env params for docker
			# This is because --env-file doesn't support newlines or quotes per https://docs.docker.com/compose/env-file/#syntax-rules
			while read -r var; do
			params+=("-e" "${var%%=*}")
			done < "${BUILDKITE_ENV_FILE}"
		else
			echo -n "🚨 Not propagating environment variables to container as \$BUILDKITE_ENV_FILE is not set"
		fi
	fi

	# Propagate AWS credentials if requested
	if [[ "$(plugin_read_config PROPAGATE_AWS_AUTH_TOKENS "false")" =~ ^(true|on|1)$ ]] ; then
		if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] ; then
			params+=( --env "AWS_ACCESS_KEY_ID" )
		fi
		if [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] ; then
			params+=( --env "AWS_SECRET_ACCESS_KEY" )
		fi
		if [[ -n "${AWS_SESSION_TOKEN:-}" ]] ; then
			params+=( --env "AWS_SESSION_TOKEN" )
		fi
		if [[ -n "${AWS_REGION:-}" ]] ; then
			params+=( --env "AWS_REGION" )
		fi
		if [[ -n "${AWS_DEFAULT_REGION:-}" ]] ; then
			params+=( --env "AWS_DEFAULT_REGION" )
		fi
		if [[ -n "${AWS_ROLE_ARN:-}" ]] ; then
			params+=( --env "AWS_ROLE_ARN" )
		fi
		if [[ -n "${AWS_STS_REGIONAL_ENDPOINTS:-}" ]] ; then
			params+=( --env "AWS_STS_REGIONAL_ENDPOINTS" )
		fi
		# Pass ECS variables when the agent is running in ECS
		# https://docs.aws.amazon.com/sdkref/latest/guide/feature-container-credentials.html
		if [[ -n "${AWS_CONTAINER_CREDENTIALS_FULL_URI:-}" ]] ; then
			params+=( --env "AWS_CONTAINER_CREDENTIALS_FULL_URI" )
		fi
		if [[ -n "${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI:-}" ]] ; then
			params+=( --env "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" )
		fi
		if [[ -n "${AWS_CONTAINER_AUTHORIZATION_TOKEN:-}" ]] ; then
			params+=( --env "AWS_CONTAINER_AUTHORIZATION_TOKEN" )
		fi
		# Pass EKS variables when the agent is running in EKS
		# https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts-minimum-sdk.html
		if [[ -n "${AWS_WEB_IDENTITY_TOKEN_FILE:-}" ]] ; then
			params+=( --env "AWS_WEB_IDENTITY_TOKEN_FILE" )
			# Add the token file as a volume
			params+=( --volume "${AWS_WEB_IDENTITY_TOKEN_FILE}:${AWS_WEB_IDENTITY_TOKEN_FILE}" )
		fi
	fi

	# If requested, propagate a set of env vars as listed in a given env var to the
	# container.
	if [[ -n "$(plugin_read_config ENV_PROPAGATION_LIST)" ]]; then
		env_propagation_list_var="$(plugin_read_config ENV_PROPAGATION_LIST)"
		if [[ -z "${!env_propagation_list_var:-}" ]]; then
			echo -n "env-propagation-list desired, but ${env_propagation_list_var} is not defined!"
			exit 1
		fi
		for var in ${!env_propagation_list_var}; do
			params+=("-e" "$var")
		done
	fi

	while IFS=$'\n' read -r vol ; do
		[[ -n "${vol:-}" ]] && params+=("-v" "$(expand_relative_volume_path "$vol")")
	done <<< "$(plugin_read_list VOLUMES)"

	# Parse BUILDKITE_DOCKER_DEFAULT_VOLUMES delimited by semi-colons, normalized to
	# ignore spaces and leading or trailing semi-colons
	IFS=';' read -r -a default_volumes <<< "${BUILDKITE_DOCKER_DEFAULT_VOLUMES:-}"
	for vol in "${default_volumes[@]:-}" ; do
		trimmed_vol="$(echo -n "$vol" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//')"
		[[ -n "$trimmed_vol" ]] && params+=("-v" "$(expand_relative_volume_path "$trimmed_vol")")
	done

	# If there's a git mirror, mount it so that git references can be followed.
	if [[ -n "${BUILDKITE_REPO_MIRROR:-}" ]]; then
		params+=("-v" "$BUILDKITE_REPO_MIRROR:$BUILDKITE_REPO_MIRROR:ro")
	fi

	# Disable allocating a TTY
	tty_default='true'
	if [[ "$(plugin_read_config TTY "$tty_default")" == "false" ]] ; then
		params+=(-T)
	fi

	workdir=''
	workdir_default="/workdir"
	pwd_default="$PWD"

	# Set operating system specific defaults
	if is_windows ; then
		workdir_default="C:\\workdir"
		# escaping /C is a necessary workaround for an issue with Git for Windows 2.24.1.2
		# https://github.com/git-for-windows/git/issues/2442
		pwd_default="$(cmd.exe //C "echo %CD%")"
	fi

	mount_checkout="$(plugin_read_config MOUNT_CHECKOUT "false")"
	if [[ -n "$(plugin_read_config WORKDIR)" ]] || [[ "${mount_checkout}" == "true" ]]; then
		workdir="$(plugin_read_config WORKDIR "$workdir_default")"
	fi

	if [[ -n "${workdir}" ]] ; then
		params+=("--workdir=${workdir}")
	fi

	if [[ "${mount_checkout}" == "true" ]]; then
		params+=("-v" "${pwd_default}:${workdir}")
	elif [[ "${mount_checkout}" =~ ^/.*$ ]]; then
		params+=("-v" "${pwd_default}:${mount_checkout}")
	elif [[ "${mount_checkout}" != "false" ]]; then
		echo -n "🚨 mount-checkout should be either true or an absolute path to use as a mountpoint"
		exit 1
	fi

	# Optionally run as specified username or uid
	if [[ -n "$(plugin_read_config USER)" ]] ; then
		params+=("--user=$(plugin_read_config USER)")
	fi

	# Optionally run as specified username or uid
	if [[ "$(plugin_read_config PROPAGATE_UID_GID "false")" == "true" ]] ; then
		params+=("--user=$(id -u):$(id -g)")
	fi

	# Enable alias support for networks
	if [[ "$(plugin_read_config USE_ALIASES "false")" == "true" ]] ; then
		params+=(--use-aliases)
	fi

	# Optionally remove containers after run
	if [[ "$(plugin_read_config RM "true")" == "true" ]]; then
		params+=(--rm)
	fi

	# Optionally sets --entrypoint
	if [[ -n "$(plugin_read_config ENTRYPOINT)" ]] ; then
		params+=(--entrypoint)
		params+=("$(plugin_read_config ENTRYPOINT)")
	fi

	# Mount ssh-agent socket and known_hosts
	if [[ ! "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_SSH_AGENT:-false}" = 'false' ]] ; then
		if [[ -z "${SSH_AUTH_SOCK:-}" ]] ; then
			echo "+++ 🚨 \$SSH_AUTH_SOCK isn't set, has ssh-agent started?"
			exit 1
		fi
		if [[ ! -S "${SSH_AUTH_SOCK}" ]] ; then
			echo "+++ 🚨 The file at ${SSH_AUTH_SOCK} does not exist or is not a socket, was ssh-agent started?"
			exit 1
		fi

		if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_SSH_AGENT:-''}" =~ ^(true|on|1)$ ]]; then
			MOUNT_PATH=/root
		else
			MOUNT_PATH="${BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_SSH_AGENT}"
		fi

		params+=(
			"-e" "SSH_AUTH_SOCK=/ssh-agent"
			"-v" "${SSH_AUTH_SOCK}:/ssh-agent"
			"-v" "${HOME}/.ssh/known_hosts:${MOUNT_PATH}/.ssh/known_hosts"
		)
	fi

	# Optionally handle the mount-buildkite-agent option
	if [[ "$(plugin_read_config MOUNT_BUILDKITE_AGENT "false")" == "true" ]]; then
		if [[ -z "${BUILDKITE_AGENT_BINARY_PATH:-}" ]] ; then
			if ! command -v buildkite-agent >/dev/null 2>&1 ; then
			echo -n "+++ 🚨 Failed to find buildkite-agent in PATH to mount into container, "
			echo "you can disable this behaviour with 'mount-buildkite-agent:false'"
			else
			BUILDKITE_AGENT_BINARY_PATH=$(command -v buildkite-agent)
			fi
		fi
	fi

	# Mount buildkite-agent if we have a path for it
	if [[ -n "${BUILDKITE_AGENT_BINARY_PATH:-}" ]] ; then
		params+=(
			"-e" "BUILDKITE_JOB_ID"
			"-e" "BUILDKITE_BUILD_ID"
			"-e" "BUILDKITE_AGENT_ACCESS_TOKEN"
			"-v" "$BUILDKITE_AGENT_BINARY_PATH:/usr/bin/buildkite-agent"
		)
	fi

	# Optionally expose service ports
	if [[ "$(plugin_read_config SERVICE_PORTS "false")" == "true" ]]; then
		params+=(--service-ports)
	fi
}