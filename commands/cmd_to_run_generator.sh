#!/bin/bash
set -uo pipefail

function generate_cmd() {
	local -n cmds="$1"
	local -n display="$2"

	shell_disabled=1
	result=()

	if [[ -n "${BUILDKITE_COMMAND}" ]]; then
		shell_disabled=''
	fi

	# Handle shell being disabled
	if [[ "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_SHELL:-}" =~ ^(false|off|0)$ ]] ; then
		shell_disabled=1

	# Show a helpful error message if a string version of shell is used
	elif [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_SHELL:-}" ]] ; then
		echo -n "🚨 The Docker Compose Plugin’s shell configuration option must be specified as an array. "
		echo -n "Please update your pipeline.yml to use an array, "
		echo "for example: [\"/bin/sh\", \"-e\", \"-u\"]."
		echo
		echo -n "Note that a shell will be inferred if one is required, so you might be able to remove"
		echo "the option entirely"
		exit 1

	# Handle shell being provided as a string or list
	elif plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMPOSE_SHELL ; then
		shell_disabled=''
		for arg in "${result[@]}" ; do
			cmds+=("$arg")
		done
	fi

	# Set a default shell if one is needed
	if [[ -z $shell_disabled ]] && [[ ${#cmds[@]} -eq 0 ]] ; then
		if is_windows ; then
			cmds=("CMD.EXE" "/c")
		# else
		# 	cmds=("/bin/sh" "-e" "-c")
		fi
	fi

	if [[ ${#cmds[@]} -gt 0 ]] ; then
		for shell_arg in "${cmds[@]}" ; do
			display+=("$shell_arg")
		done
	fi

	# Show a helpful error message if string version of command is used
	if [[ -n "${BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND:-}" ]] ; then
		echo "🚨 The Docker Compose Plugin’s command configuration option must be an array."
		exit 1
	fi

	# Parse plugin command if provided
	if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND ; then
		if [[ "${#result[@]}" -gt 0 ]] && [[ -n "${BUILDKITE_COMMAND}" ]] ; then
			echo "+++ Error: Can't use both a step level command and the command parameter of the plugin"
			exit 1
		elif [[ "${#result[@]}" -gt 0 ]] ; then
			echo "compose plugin command: ${result[@]}"
			for arg in "${result[@]}" ; do
			cmds+=("$arg")
			display+=("$arg")
			done
		fi
	fi
	if [[ -n "${BUILDKITE_COMMAND}" ]] ; then
		echo "buildkite command: ${BUILDKITE_COMMAND}"
		if [[ $(echo "$BUILDKITE_COMMAND" | wc -l) -gt 1 ]]; then
			# FIXME: This is easy to fix, just need to do at end

			# An array of commands in the step will be a single string with multiple lines
			# This breaks a lot of things here so we will print a warning for user to be aware
			echo "⚠️  Warning: The command received has multiple lines."
			echo "⚠️           The Docker Compose Plugin does not correctly support step-level array commands."
		fi
		cmds+=("${BUILDKITE_COMMAND}")
		display+=("'${BUILDKITE_COMMAND}'")
	fi
}