#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared'
load '../lib/run'

# export DOCKER_COMPOSE_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty
# export BATS_MOCK_TMPDIR=$PWD

setup_file() {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN_LABELS="false"
}

@test "Run without a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image and an empty command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "The Docker Compose Plugin does not correctly support step-level array commands"
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image and a custom workdir" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WORKDIR=/test_workdir
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --workdir=/test_workdir --rm myservice : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with a quoted command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="sh -c 'echo hello world'"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c $'sh -c \'echo hello world\'' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with a multi-line command" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="cmd1
cmd2
cmd3"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c $'cmd1\ncmd2\ncmd3' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "The Docker Compose Plugin does not correctly support step-level array commands"
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with a command config" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_0=echo
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice echo 'hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "The Docker Compose Plugin does not correctly support step-level array commands"
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with custom env" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENV_0=MYENV=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENV_1=MYENV
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENVIRONMENT_0=MYENV=2
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENVIRONMENT_1=MYENV
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENVIRONMENT_2=ANOTHER="this is a long string with spaces; and semi-colons"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -e MYENV=0 -e MYENV -e MYENV=2 -e MYENV -e ANOTHER=this\ is\ a\ long\ string\ with\ spaces\;\ and\ semi-colons --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with no-cache" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --no-cache myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image with build args" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_0=MYARG=0
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ARGS_1=MYARG=1
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --build-arg MYARG=0 --build-arg MYARG=1 myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a prebuilt image and propagate environment but no BUILDKITE_ENV_FILE" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROPAGATE_ENVIRONMENT=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Running /bin/sh -e -c 'pwd' in service myservice"
  assert_output --partial "Not propagating environment variables to container"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a prebuilt image and propagate environment" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_ENV_FILE=/tmp/test_env
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROPAGATE_ENVIRONMENT=true

  echo "VAR0=1" > "${BUILDKITE_ENV_FILE}"
  echo "VAR2=lalala" >> "${BUILDKITE_ENV_FILE}"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -e \* -e \* --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with vars \${11} and \${13}"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Running /bin/sh -e -c 'pwd' in service myservice"
  assert_output --partial "ran myservice with vars VAR0 and VAR2"

  unstub docker-compose
  unstub buildkite-agent

  rm "${BUILDKITE_ENV_FILE}"
}

@test "Run with a prebuilt image" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a prebuilt image and custom config file" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a prebuilt image and multiple custom config files" {
export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1=tests/composefiles/docker-compose.v2.1.yml
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -f tests/composefiles/docker-compose.v2.1.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f tests/composefiles/docker-compose.v2.0.yml -f tests/composefiles/docker-compose.v2.1.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo pulled myservice" \
    "-f tests/composefiles/docker-compose.v2.0.yml -f tests/composefiles/docker-compose.v2.1.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml-tests/composefiles/docker-compose.v2.1.yml : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml-tests/composefiles/docker-compose.v2.1.yml : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a prebuilt image and custom config file set from COMPOSE_FILE" {
  export COMPOSE_FILE=tests/composefiles/docker-compose.v2.0.yml
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f tests/composefiles/docker-compose.v2.0.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice-tests/composefiles/docker-compose.v2.0.yml : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a single prebuilt image, no retry on failed pull" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : exit 2"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Exited with 2"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a single prebuilt image, retry on failed pull" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_RETRIES=3

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : exit 2" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a TTY" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_TTY=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -T --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice without tty"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice without tty"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without dependencies" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_DEPENDENCIES=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --no-deps --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice without dependencies"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice without dependencies"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with dependencies but in a single step" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PRE_RUN_DEPENDENCIES=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with dependencies"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with dependencies"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without ansi output" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ANSI=false

  stub docker-compose \
    "--no-ansi -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "--no-ansi -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "--no-ansi -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice without ansi output"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice without ansi output"
  unstub docker-compose
  unstub buildkite-agent
}


@test "Run without pull" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SKIP_PULL=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice without pull"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Running /bin/sh -e -c 'pwd' in service myservice"
  assert_output --partial "ran myservice without pull"
  
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with use aliases" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_USE_ALIASES=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --use-aliases --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with use aliases output"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with use aliases output"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with compatibility mode" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COMPATIBILITY=true

  stub docker-compose \
    "--compatibility -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "--compatibility -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "--compatibility -f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with use aliases output"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with use aliases output"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a volumes option" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_0="./dist:/app/dist"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_1="./pkg:/app/pkg"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v $PWD/dist:/app/dist -v $PWD/pkg:/app/pkg --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with an external volume" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES="buildkite:/buildkite"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v buildkite:/buildkite --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with default volumes, extra delimiters" {
  # Tests introduction of extra delimiters, as would occur if
  # EXPORT BUILDKITE_DOCKER_DEFAULT_VOLUMES="new:mount; ${BUILDKITE_DOCKER_DEFAULT_VOLUMES:-}"
  # was used with no existing value
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_DOCKER_DEFAULT_VOLUMES="buildkite:/buildkite; ./dist:/app/dist;; ;   ;"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v buildkite:/buildkite -v $PWD/dist:/app/dist --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with volumes with variables" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_0="\$SUPER_VARIABLE:/mnt"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_1="/:\$OTHER_VARIABLE"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_2="\$RELATIVE_VARIABLE:/srv"

  export SUPER_VARIABLE='/test/path'
  export OTHER_VARIABLE='/path/tested'
  export RELATIVE_VARIABLE='./path'

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v \\\$SUPER_VARIABLE:/mnt -v /:\\\$OTHER_VARIABLE -v \\\$RELATIVE_VARIABLE:/srv --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}


@test "Run with volumes with variables but option turned off" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_EXPAND_VOLUME_VARS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_0="\$SUPER_VARIABLE:/mnt"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_1="/:\$OTHER_VARIABLE"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_2="\$RELATIVE_VARIABLE:/srv"


  export SUPER_VARIABLE='/test/path'
  export OTHER_VARIABLE='/path/tested'
  export RELATIVE_VARIABLE='./path'

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v \\\$SUPER_VARIABLE:/mnt -v /:\\\$OTHER_VARIABLE -v \\\$RELATIVE_VARIABLE:/srv --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with volumes with variables and option turned on" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_EXPAND_VOLUME_VARS=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_0="\$SUPER_VARIABLE:/mnt"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_1="/:\$OTHER_VARIABLE"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_VOLUMES_2="\$RELATIVE_VARIABLE:/srv"


  export SUPER_VARIABLE='/test/path'
  export OTHER_VARIABLE='/path/tested'
  export RELATIVE_VARIABLE='./path'

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v /test/path:/mnt -v /:/path/tested -v $PWD/path:/srv --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with default volumes" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_DOCKER_DEFAULT_VOLUMES="buildkite:/buildkite;./dist:/app/dist"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 -v buildkite:/buildkite -v $PWD/dist:/app/dist --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with volumes"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with volumes"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with multiple config files" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_0="llamas1.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_1="llamas2.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CONFIG_2="llamas3.yml"

  stub docker-compose \
    "-f llamas1.yml -f llamas2.yml -f llamas3.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f llamas1.yml -f llamas2.yml -f llamas3.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f llamas1.yml -f llamas2.yml -f llamas3.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice-llamas1.yml-llamas2.yml-llamas3.yml : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a failure should expand previous group" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : exit 2"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "^^^ +++"
  assert_output --partial "Failed to run command, exited with 2"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with multiple prebuilt images and multiple pulls" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_0=myservice1
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_1=myservice2
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull --parallel myservice1 myservice2 : echo pulled myservice1 and myservice2" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice1=0 myservice1 : echo started dependencies for myservice1" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice1_build_1 --rm myservice1 /bin/sh -e -c 'pwd' : echo ran myservice1"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice1 : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice1 : echo myimage1" \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice2 : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice2 : echo myimage2"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled myservice1 and myservice2"
  assert_output --partial "ran myservice1"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image and a custom user" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="sh -c 'whoami'"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_USER="1000"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --user=1000 --rm myservice /bin/sh -e -c $'sh -c \'whoami\'' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without a prebuilt image and a custom user and group" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="sh -c 'whoami'"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_USER="1000:1001"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --user=1000:1001 --rm myservice /bin/sh -e -c $'sh -c \'whoami\'' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Fail with custom user and propagate UIDs" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="sh -c 'whoami'"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_USER="1000:1001"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_PROPAGATE_UID_GID="true"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Error"
  assert_output --partial "Can't set both user and propagate-uid-gid"
  unstub buildkite-agent
}


@test "Run without --rm" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RM=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 myservice /bin/sh -e -c $'pwd' : echo ran myservice without tty"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice without tty"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with custom entrypoint" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENTRYPOINT="my custom entrypoint"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm --entrypoint 'my custom entrypoint' myservice : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-buildkite-agent enabled" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=""
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_BUILDKITE_AGENT=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm -e BUILDKITE_JOB_ID -e BUILDKITE_BUILD_ID -e BUILDKITE_AGENT_ACCESS_TOKEN -v $BATS_MOCK_TMPDIR/bin/buildkite-agent:/usr/bin/buildkite-agent myservice : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with various build arguments" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_NO_CACHE=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_PARALLEL=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull --no-cache --parallel myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with git-mirrors" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_REPO_MIRROR=/tmp/sample-mirror

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -v /tmp/sample-mirror:/tmp/sample-mirror:ro --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-ssh-agent" {
  export SSH_AUTH_SOCK=/tmp/ssh_auth_sock
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_SSH_AGENT=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm -e SSH_AUTH_SOCK=/ssh-agent -v /tmp/ssh_auth_sock:/ssh-agent -v /root/.ssh/known_hosts:/root/.ssh/known_hosts myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  apk add netcat-openbsd
  nc -lkvU $SSH_AUTH_SOCK &

  run "$PWD"/hooks/command

  assert_success

  kill %1

  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-ssh-agent on particular folder" {
  export SSH_AUTH_SOCK=/tmp/ssh_auth_sock
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_SSH_AGENT=/tmp/test

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm -e SSH_AUTH_SOCK=/ssh-agent -v /tmp/ssh_auth_sock:/ssh-agent -v /root/.ssh/known_hosts:/tmp/test/.ssh/known_hosts myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  apk add netcat-openbsd
  nc -lkvU $SSH_AUTH_SOCK &

  run "$PWD"/hooks/command

  assert_success

  kill %1

  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run without mount-checkout doesn't set volume" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice without mount-checkout"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice without mount-checkout"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-checkout set to true" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --workdir=/workdir -v $PWD:/workdir --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with mount-checkout"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with mount-checkout"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-checkout set to true with custom workdir" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT=true
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WORKDIR="/custom_workdir"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --workdir=$BUILDKITE_PLUGIN_DOCKER_COMPOSE_WORKDIR -v $PWD:$BUILDKITE_PLUGIN_DOCKER_COMPOSE_WORKDIR --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with mount-checkout"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with mount-checkout"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-checkout set to specific path" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_COMMAND=pwd

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT="/special"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f \* pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f \* up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f \* run --name buildkite1111_myservice_build_1 -v \* --rm myservice /bin/sh -e -c 'pwd' : echo ran myservice with mount-checkout on \${11}"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with mount-checkout on /plugin:/special"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-checkout set to specific path and workdir set" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_COMMAND=pwd

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT="/special"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WORKDIR="/custom_workdir"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f \* pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f \* up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f \* run --name buildkite1111_myservice_build_1 \* -v \* --rm myservice /bin/sh -e -c 'pwd' : echo echo ran myservice with mount-checkout on \${12}"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice with mount-checkout on /plugin:/special"
  assert_output --partial "--workdir=/custom_workdir"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-checkout set something else" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_COMMAND=pwd

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT="not_absolute"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f \* pull myservice : echo pulled myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "mount-checkout should be either true or an absolute path to use as a mountpoint"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with mount-checkout set something else and workdir set" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_COMMAND=pwd

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_MOUNT_CHECKOUT="not-absolute"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WORKDIR="/custom_workdir"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f \* pull myservice : echo pulled myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 0" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "mount-checkout should be either true or an absolute path to use as a mountpoint"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run waiting for dependencies" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_WAIT=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up --wait -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Starting dependencies"
  assert_output --partial "ran myservice"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with --service-ports" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_SERVICE_PORTS=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 --rm --service-ports myservice /bin/sh -e -c $'pwd' : echo ran myservice without tty"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice without tty"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with Docker labels" {
  # Pipeline vars
  export BUILDKITE_AGENT_ID="1234"
  export BUILDKITE_AGENT_NAME="agent"
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_LABEL="Testjob"
  export BUILDKITE_PIPELINE_NAME="label-test"
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_STEP_KEY="test-job"

  # Plugin config
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN_LABELS="true"

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml pull myservice : echo pulled myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml up -d --scale myservice=0 myservice : echo started dependencies for myservice" \
    "-f docker-compose.yml -p buildkite1111 -f docker-compose.buildkite-1-override.yml run --name buildkite1111_myservice_build_1 \
      --label com.buildkite.pipeline_name=${BUILDKITE_PIPELINE_NAME} \
      --label com.buildkite.pipeline_slug=${BUILDKITE_PIPELINE_SLUG} \
      --label com.buildkite.build_number=${BUILDKITE_BUILD_NUMBER} \
      --label com.buildkite.job_id=${BUILDKITE_JOB_ID} \
      --label com.buildkite.job_label=${BUILDKITE_LABEL} \
      --label com.buildkite.step_key=${BUILDKITE_STEP_KEY} \
      --label com.buildkite.agent_name=${BUILDKITE_AGENT_NAME} \
      --label com.buildkite.agent_id=${BUILDKITE_AGENT_ID} \
      --rm myservice /bin/sh -e -c $'pwd' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : echo myimage" \
    "meta-data get docker-compose-plugin-built-image-tag-myservice : echo myimage"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with --quiet-pull" {
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PIPELINE_SLUG=test

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_QUIET_PULL=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up --quiet-pull -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  refute_output --partial "Pulling"
  assert_output --partial "ran myservice"

  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a list of propagated env vars" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENV_PROPAGATION_LIST="LIST_OF_VARS"
  export LIST_OF_VARS="VAR_A VAR_B VAR_C"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 -e VAR_A -e VAR_B -e VAR_C --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "built myservice"
  assert_output --partial "ran myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with a list of propagated env vars - unless you forgot to define the variable" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_ENV_PROPAGATION_LIST="LIST_OF_VARS"
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "env-propagation-list desired, but LIST_OF_VARS is not defined!"
  unstub buildkite-agent
}

@test "Run with expanded run log group by default" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "+++ :docker: Running /bin/sh -e -c 'echo hello world' in service myservice"
  unstub docker-compose
  unstub buildkite-agent
}

@test "Run with collapsed run log group" {
  export BUILDKITE_JOB_ID=1111
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_RUN=myservice
  export BUILDKITE_PIPELINE_SLUG=test
  export BUILDKITE_BUILD_NUMBER=1
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CHECK_LINKED_CONTAINERS=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_COLLAPSE_RUN_LOG_GROUP=true

  stub docker-compose \
    "-f docker-compose.yml -p buildkite1111 build --pull myservice : echo built myservice" \
    "-f docker-compose.yml -p buildkite1111 up -d --scale myservice=0 myservice : echo ran myservice dependencies" \
    "-f docker-compose.yml -p buildkite1111 run --name buildkite1111_myservice_build_1 --rm myservice /bin/sh -e -c 'echo hello world' : echo ran myservice"

  stub buildkite-agent \
    "meta-data exists docker-compose-plugin-built-image-tag-myservice : exit 1"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "--- :docker: Running /bin/sh -e -c 'echo hello world' in service myservice"
  unstub docker-compose
  unstub buildkite-agent


}
