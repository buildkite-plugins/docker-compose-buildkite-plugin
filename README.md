# Docker Compose Buildkite Plugin [![Build status](https://badge.buildkite.com/a1d1805d117ec32791cb22055aedc5ff709f1498024295bef0.svg?branch=master)](https://buildkite.com/buildkite/plugins-docker-compose)

This fork of Buildkite's default plugin. It allows for the skipping of build
steps if an image with the specified tag already exists. This can dramatically
speed up certain steps such as dependency installs or asset builds if your
images are tagged with a proper cache key.

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) that lets you build, run and push build steps using [Docker Compose](https://docs.docker.com/compose/).

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building of images, allowing for fast parallel builds across distributed agents
* Supports pushing tagged images to a repository

## Example

The following pipeline will run `test.sh` inside a `app` service container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v4.16.0:
          run: app
```

:warning: Warning: you should not use this plugin with an array of commands at the step level. Execute a script in your repository, a single command separated by `;` or the plugin's [`command` option](#command-optional-run-only-array) instead.

You can also specify a custom Docker Compose config file and what environment to pass
through if you need:

```yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v4.16.0:
          run: app
          config: docker-compose.tests.yml
          env:
            - BUILDKITE_BUILD_NUMBER
```

or multiple config files:

```yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v4.16.0:
          run: app
          config:
            - docker-compose.yml
            - docker-compose.test.yml
```

You can also specify the Docker Compose config file with [`$COMPOSE_FILE`](https://docs.docker.com/compose/reference/envvars/#compose_file):

```yml
env:
  COMPOSE_FILE: docker-compose.yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v4.16.0:
          run: app
```

If you want to control how your command is passed to docker-compose, you can use the command parameter on the plugin directly:

```yml
steps:
  - plugins:
      - docker-compose#v4.16.0:
          run: app
          command: ["custom", "command", "values"]
```

## Authenticated registries

You can leverage the [docker-login plugin](https://github.com/buildkite-plugins/docker-login-buildkite-plugin) in tandem for authenticating with a registry. For example, the following will build and push an image to a private repo, and pull from that private repo in subsequent run commands:

```yml
steps:
  - plugins:
      - docker-login#v2.0.1:
          username: xyz
      - docker-compose#v4.16.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
  - wait
  - command: test.sh
    plugins:
      - docker-login#v2.0.1:
          username: xyz
      - docker-compose#v4.16.0:
          run: app
```

Note, you will need to add the configuration to all steps in which you use this plugin.

## Artifacts

If you’re generating artifacts in the build step, you’ll need to ensure your Docker Compose configuration volume mounts the host machine directory into the container where those artifacts are created.

For example, if you had the following step:

```yml
steps:
  - command: generate-dist.sh
    artifact_paths: "dist/*"
    plugins:
      - docker-compose#v4.16.0:
          run: app
```

Assuming your application’s directory inside the container was `/app`, you would need to ensure your `app` service in your Docker Compose config has the following host volume mount:

```yml
volumes:
  - "./dist:/app/dist"
```

You can also use the `volumes` plugin option to add or override a volume, for example:

```yml
steps:
  - command: generate-dist.sh
    artifact_paths: "dist/*"
    plugins:
      - docker-compose#v4.16.0:
          run: app
          volumes:
            - "./dist:/app/dist"
```

If you want to use environment variables in the `volumes` element, you will need to activate the (unsafe) option `expand-volume-vars` (and most likely escape it using `$$VARIABLE_NAME`).

## Environment

By default, docker-compose makes whatever environment variables it gets available for
interpolation of docker-compose.yml, but it doesn't pass them in to your containers.

You can use the [environment key in docker-compose.yml](https://docs.docker.com/compose/environment-variables/) to either set specific environment vars or "pass through" environment variables from outside docker-compose.

### Specific values

If you want to add extra environment above what is declared in your `docker-compose.yml`,
this plugin offers a `environment` block of its own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      - docker-compose#v4.16.0:
          run: app
          env:
            - BUILDKITE_BUILD_NUMBER
            - BUILDKITE_PULL_REQUEST
            - MY_CUSTOM_ENV=llamas
```

Note how the values in the list can either be just a key (so the value is sourced from the environment) or a KEY=VALUE pair.

### Pipeline variables

Alternatively, you can have the plugin add all environment variables defined for the job by the agent as defined in [`BUILDKITE_ENV_FILE`](https://buildkite.com/docs/pipelines/environment-variables#BUILDKITE_ENV_FILE) activating the `propagate-environment` option:

```yml
steps:
  - command: use-vars.sh
    plugins:
      - docker-compose#v4.16.0:
          run: app
          propagate-environment: true
```

## Container Labels

When running a command, the plugin will automatically add the following Docker labels to the container specified in the `run` option:
- `com.buildkite.pipeline_name=${BUILDKITE_PIPELINE_NAME}`
- `com.buildkite.pipeline_slug=${BUILDKITE_PIPELINE_SLUG}`
- `com.buildkite.build_number=${BUILDKITE_BUILD_NUMBER}`
- `com.buildkite.job_id=${BUILDKITE_JOB_ID}`
- `com.buildkite.job_label=${BUILDKITE_LABEL}`
- `com.buildkite.step_key=${BUILDKITE_STEP_KEY}`
- `com.buildkite.agent_name=${BUILDKITE_AGENT_NAME}`
- `com.buildkite.agent_id=${BUILDKITE_AGENT_ID}`

These labels can make it easier to query containers on hosts using `docker ps` for example:

```bash
docker ps --filter "label=com.buildkite.job_label=Run tests"
```

This behaviour can be disabled with the `run-labels: false` option.

## Build Arguments

You can use the [build args key in docker-compose.yml](https://docs.docker.com/compose/compose-file/build/#args) to set specific build arguments when building an image.

Alternatively, if you want to set build arguments when pre-building an image, this plugin offers an `args` block of its own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      - docker-compose#v4.16.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
          args:
            - MY_CUSTOM_ARG=panda
```

Note that the values in the list must be a `KEY=VALUE` pair.

## Pre-building the image

If you have multiple steps that use the same service/image (such as steps that run in parallel), you can use this plugin in a specific `build` step to your pipeline. That will set specific metadata in the pipeline for this plugin to use in `run` steps afterwards:

```yml
steps:
  - label: ":docker: Build"
    plugins:
      - docker-compose#v4.16.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo

  - wait

  - label: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      - docker-compose#v4.16.0:
          run: app
```

All `run` steps for the service `app` will automatically pull and use the pre-built image. Without this, each `Test %n` job would build its own instead.

## Building multiple images

Sometimes your compose file has multiple services that need building. The example below will build images for the `app` and `tests` service and then the run step will pull them down and use them for the run as needed.

```yml
steps:
  - label: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      - docker-compose#v4.16.0:
          build:
            - app
            - tests
          image-repository: index.docker.io/myorg/myrepo

  - wait

  - label: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      - docker-compose#v4.16.0:
          run: tests
```

## Pushing Tagged Images

If you want to push your Docker images ready for deployment, you can use the `push` configuration (which operates similar to [docker-compose push](https://docs.docker.com/compose/reference/push/):

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v4.16.0:
          push: app
```

To push multiple images, you can use a list:

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v4.16.0:
          push:
            - first-service
            - second-service
```

If you want to push to a specific location (that's not defined as the `image` in your docker-compose.yml), you can use the `{service}:{repo}:{tag}` format, for example:

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v4.16.0:
          push:
            - app:index.docker.io/myorg/myrepo/myapp
            - app:index.docker.io/myorg/myrepo/myapp:latest
```

## Reusing caches from images

A newly spawned agent won't contain any of the docker caches for the first run which will result in a long build step. To mitigate this you can reuse caches from a previously built image (if it was pushed from a previous build):

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v4.16.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
          cache-from: app:index.docker.io/myorg/myrepo/myapp:latest
  - wait
  - label: ":docker: Push to final repository"
    plugins:
      - docker-compose#v4.16.0:
          push:
            - app:index.docker.io/myorg/myrepo/myapp
            - app:index.docker.io/myorg/myrepo/myapp:latest
```

**Important**: if your registry URL contains a port, you will need to take the following into account:
* specify the `separator-cache-from` option to change the colon character to something else (like `#`)
* you will have to specify tags in the `push` elements (or the plugin will try to validate everything after the port as a tag)

#### Multiple cache-from values

This plugin allows for the value of `cache-from` to be a string or a list. If it's a list, as below, then the first successfully pulled image will be used.

```yaml
steps:
  - label: ":docker Build an image"
    plugins:
      - docker-compose#v4.16.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
          separator-cache-from: "#"
          cache-from:
            - "app#myregistry:port/myrepo/myapp#my-branch"
            - "app#myregistry:port/myrepo/myapp#latest"
  - wait
  - label: ":docker: Push to final repository"
    plugins:
      - docker-compose#v4.16.0:
          push:
            - app:myregistry:port/myrepo/myapp:my-branch
            - app:myregistry:port/myrepo/myapp:latest
```

You may actually want to build your image with multiple cache-from values, for instance, with the cached images of multiple stages in a multi-stage build.
Adding a grouping tag to the end of a cache-from list item allows this plugin to differentiate between groups within which only the first successfully downloaded image should be used (those elements that don't have a group specified will make a separate `:default:` group of its own). This way, not all images need to be downloaded and used as cache, not just the first.

```yaml
steps:
  - label: ":docker: Build Intermediate Image"
    plugins:
      - docker-compose#v4.16.0:
          build: myservice_intermediate  # docker-compose.yml is the same as myservice but has `target: intermediate`
          image-name: buildkite-build-${BUILDKITE_BUILD_NUMBER}
          image-repository: index.docker.io/myorg/myrepo/myservice_intermediate
          cache-from:
            - myservice_intermediate:index.docker.io/myorg/myrepo/myservice_intermediate:${BUILDKITE_BRANCH}
            - myservice_intermediate:index.docker.io/myorg/myrepo/myservice_intermediate:latest
  - wait
  - label: ":docker: Build Final Image"
    plugins:
      - docker-compose#v4.16.0:
          build: myservice
          image-name: buildkite-build-${BUILDKITE_BUILD_NUMBER}
          image-repository: index.docker.io/myorg/myrepo
          cache-from:
            - myservice:index.docker.io/myorg/myrepo/myservice_intermediate:buildkite-build-${BUILDKITE_BUILD_NUMBER}:intermediate  # built in step above
            - myservice:index.docker.io/myorg/myrepo/myservice:${BUILDKITE_BRANCH}
            - myservice:index.docker.io/myorg/myrepo/myservice:latest

```

In the example above, the `myservice_intermediate:buildkite-build-${BUILDKITE_BUILD_NUMBER}` is one group named "intermediate", and `myservice:${BUILDKITE_BRANCH}` and `myservice:latest`
are another (with a default name). The first successfully downloaded image in each group will be used as a cache.

## Configuration

### Main Commands

You will need to specify at least one of the following to use this extension.

#### `build`

The name of a service to build and store, allowing following pipeline steps to run faster as they won't need to build the image. The step's `command` will be ignored and does not need to be specified.

Either a single service or multiple services can be provided as an array.

#### `run`

The name of the service the command should be run within. If the docker-compose command would usually be `docker-compose run app test.sh` then the value would be `app`.

#### `push`

A list of services to push in the format `service:image:tag`. If an image has been pre-built with the build step, that image will be re-tagged, otherwise docker-compose's built-in push operation will be used.

#### Known issues

##### Run & Push

A basic pipeline similar to the following:

```yaml
steps:
  - label: ":docker: Run & Push"
    plugins:
      - docker-compose#v4.16.0:
          run: myservice
          push: myservice
```

Will cause the image to be built twice (once before running and once before pushing) unless there was a previous `build` step that set the appropriate metadata.

##### Build & Push

A basic pipeline similar to the following:

```yaml
steps:
  - label: ":docker: Build & Push"
    plugins:
      - docker-compose#v4.16.0:
          build: myservice
          push: myservice
```

Will cause the image to be pushed twice (once by the build step and another by the push step)

### `pull` (optional, run only)

Pull down multiple pre-built images. By default only the service that is being run will be pulled down, but this allows multiple images to be specified to handle prebuilt dependent images. Note that pulling will be skipped if the `skip-pull` option is activated.

### `collapse-run-log-group` (optional, boolean, run only)

Whether to collapse or expand the log group that is created for the output of `docker-compose run`. When this setting is `true`, the output is collected into a `---` group, when `false` the output is collected into a `+++` group. Setting this to `true` can be useful to de-emphasize plugin output if your command creates its own `+++` group.

For more information see [Managing log output](https://buildkite.com/docs/pipelines/managing-log-output).

Default `false`

### `config` (optional)

The file name of the Docker Compose configuration file to use. Can also be a list of filenames. If `$COMPOSE_FILE` is set, it will be used if `config` is not specified.

Default: `docker-compose.yml`

### `image-repository` (optional, build only)

The repository for pushing and pulling pre-built images, same as the repository location you would use for a `docker push`, for example `"index.docker.io/myorg/myrepo"`. Each image is tagged to the specific build so you can safely share the same image repository for any number of projects and builds.

The default is `""` which only builds images on the local Docker host doing the build.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY`.

### `image-name` (optional, build only)

The name to use when tagging pre-built images. If multiple images are built in the build phase, you must provide an array of image names.

### `build-alias` (optional, build only)

Other docker-compose services that should be aliased to the main service that was built. This is for when different docker-compose services share the same prebuilt image.

### `args` (optional, build and run only)

A list of KEY=VALUE that are passed through as build arguments when image is being built.

### `env` or `environment` (optional, run only)

A list of either KEY or KEY=VALUE that are passed through as environment variables to the container.

### `env-propagation-list` (optional, string)

If you set this to `VALUE`, and `VALUE` is an environment variable containing a space-separated list of environment variables such as `A B C D`, then A, B, C, and D will all be propagated to the container. This is helpful when you've set up an `environment` hook to export secrets as environment variables, and you'd also like to programmatically ensure that secrets get propagated to containers, instead of listing them all out.

### `propagate-environment` (optional, boolean)

Whether or not to automatically propagate all pipeline environment variables into the run container. Avoiding the need to be specified with environment.

**Important**: only pipeline environment variables will be propagated (what you see in the BuildKite UI, those listed in `$BUILDKITE_ENV_FILE`). This does not include variables exported in preceeding `environment` hooks. If you wish for those to be propagated you will need to list them specifically or use `env-propagation-list`.

### `command` (optional, run only, array)

Sets the command for the Docker image, and defaults the `shell` option to `false`. Useful if the Docker image has an entrypoint, or doesn't contain a shell.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

### `shell` (optional, run only, array or boolean)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker-compose run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided a `command`.

Example: `[ "powershell", "-Command" ]`

### `skip-checkout` (optional, run only)

Whether to skip the repository checkout phase. This is useful for steps that use a pre-built image and will fail if there is no pre-built image.

**Important**: as the code repository will not be available in the step, you need to ensure that the docker compose file(s) are present in some way (like using artifacts)

### `skip-pull` (optional, build and run only)

Completely avoid running any `pull` command. Images being used will need to be present in the machine from before or have been built in the same step. Could be useful to avoid hitting rate limits when you can be sure the operation is unnecessary. Note that it is possible other commands run in the plugin's lifecycle will trigger a pull of necessary images.

### `workdir` (optional, run only)

Specify the container working directory via `docker-compose run --workdir`. This option is also used by [`mount-checkout`](#mount-checkout-optional-run-only-boolean) if it doesn't specify where to mount the checkout in the container.

Example: `/app`

### `user` (optional, run only)

Run as specified username or uid via `docker-compose run --user`.

### `propagate-uid-gid` (optional, run-only, boolean)

Whether to match the user ID and group ID for the container user to the user ID and group ID for the host user. It is similar to specifying user: 1000:1000, except it avoids hardcoding a particular user/group ID.

Using this option ensures that any files created on shared mounts from within the container will be accessible to the host user. It is otherwise common to accidentally create root-owned files that Buildkite will be unable to remove, since containers by default run as the root user.

### `mount-ssh-agent` (optional, run-only, boolean or string)

Whether to mount the ssh-agent socket (at `/ssh-agent`) from the host agent machine into the container or not. Instead of just `true` or `false`, you can specify absolute path in the container for the home directory of the user used to run on which the agent's `.ssh/known_hosts` will be mounted (by default, `/root`).

Default: `false`

### `mount-buildkite-agent` (optional, run-only, boolean)

Whether to automatically mount the `buildkite-agent` binary and associated environment variables from the host agent machine into the container.

Default: `false`

### `mount-checkout` (optional, run-only, string or boolean)

The absolute path where to mount the current working directory which contains your checked out codebase.

If set to `true` it will mount onto `/workdir`, unless `workdir` is set, in which case that will be used.

Default: `false`

### `pull-retries` (optional)

A number of times to retry failed docker pull. Defaults to 0.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_RETRIES`.

### `push-retries` (optional)

A number of times to retry failed docker push. Defaults to 0.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_RETRIES`.

### `cache-from` (optional, build only)

A list of images to attempt pulling before building in the format `service:index.docker.io/myorg/myrepo/myapp:tag:group`, ignoring any failures, to allow docker to re-use layers. The parameters `service` and `image-repo` are mandatory, without them it won't work. For each combination of service and group, it will attempt to pull each in order until one is successful (the rest will be ignored). Those elements that don't have a group specified will use a `:default:` group.
Requires docker-compose file version `3.2+`.

### `separator-cache-from` (optional, build only, single character)

A single character that specifies the character to use for splitting elements in the `cache-from` option.

By default it is `:` which should not be a problem unless your registry's URL contains a port, in which case you will have to use this option to specify a different character.

**Important**: the tag to use is its own field, so you will have to specify elements like `service#registry:port/myrepo/myapp#tag#group`

### `target` (optional, build only)

Allow for intermediate builds with `--target VALUE` options.

Note that there is a single build command run for all services so the target value will apply to all of them.

### `volumes` (optional, run only)

A list of volumes to mount into the container. If a matching volume exists in the Docker Compose config file, this option will override that definition.

Additionally, volumes may be specified via the agent environment variable `BUILDKITE_DOCKER_DEFAULT_VOLUMES`, a `;` (semicolon)  delimited list of mounts in the `-v` syntax. (Ex. `buildkite:/buildkite;./app:/app`).

### `expand-volume-vars` (optional, boolean, run only, unsafe)

When set to true, it will activate interpolation of variables in the elements of the `volumes` configuration array. When turned off (the default), attempting to use variables will fail as the literal `$VARIABLE_NAME` string will be passed to the `-v` option.

:warning: **Important:** this is considered an unsafe option as the most compatible way to achieve this is to run the strings through `eval` which could lead to arbitrary code execution or information leaking if you don't have complete control of the pipeline

Note that rules regarding [environment variable interpolation](https://buildkite.com/docs/pipelines/environment-variables#runtime-variable-interpolation) apply here. That means that `$VARIABLE_NAME` is resolved at pipeline upload time, whereas `$$VARIABLE_NAME` will be at run time. All things being equal, you likely want to use `$$VARIABLE_NAME` on the variables mentioned in this option.

### `graceful-shutdown` (optional, run only)

Gracefully shuts down all containers via 'docker-compose stop`.

The default is `false`.

### `leave-volumes` (optional, run only)

Prevent the removal of volumes after the command has been run.

The default is `false`.

### `no-cache` (optional, build and run only)

Build with `--no-cache`, causing Docker Compose to not use any caches when building the image.

The default is `false`.

### `build-parallel` (optional, build and run only)

Build with `--parallel`, causing Docker Compose to run builds in parallel. Requires docker-compose `1.23+`.

The default is `false`.

### `tty` (optional, run only)

If set to false, doesn't allocate a TTY. This is useful in some situations where TTY's aren't supported, for instance windows.

The default is `true` on unix, `false` on windows

### `dependencies` (optional, run only)

If set to false, runs with `--no-deps` and doesn't start linked services.

The default is `true`.

### `pre-run-dependencies` (optional, run only)

If `dependencies` are activated (which is the default), you can skip starting them up before the main container by setting this option to `false`. This is useful if you want compose to take care of that on its own at the expense of messier output in the run step.

### `wait` (optional, run only)

Whether to wait for dependencies to be up (and healthy if possible) when starting them up. It translates to using [`--wait` in the docker-compose up] command.

Defaults to `false`.

### `ansi` (optional, run only)

If set to false, disables the ansi output from containers.

The default is `true`.

### `use-aliases` (optional, run only)

If set to true, docker compose will use the service's network aliases in the network(s) the container connects to.

The default is `false`.

### `verbose` (optional)

Sets `docker-compose` to run with `--verbose`

The default is `false`.

### `quiet-pull` (optional, run only)

Start up dependencies with `--quiet-pull` to prevent even more logs during that portion of the execution.

The default is `false`.

### `rm` (optional, run only)

If set to true, docker compose will remove the primary container after run. Equivalent to `--rm` in docker-compose.

The default is `true`.

### `run-labels` (optional, run only)

If set to true, adds useful Docker labels to the primary container. See [Container Labels](#container-labels) for more info.

The default is `true`.

### `compatibility` (optional, run only)

If set to true, all docker compose commands will rum with compatibility mode. Equivalent to `--compatibility` in docker-compose.

The default is `false`.

Note that [the effect of this option changes depending on your docker compose CLI version](https://docs.docker.com/compose/cli-command-compatibility/#flags-that-will-not-be-implemented):
* in v1 it translates (composefile) v3 deploy keys to their non-swarm (composefile) v2 equivalents
* in v2 it will revert some behaviour to v1 as well, including (but not limited to):
  - [Character separator for container names](https://github.com/docker/compose/blob/a0acc20d883ce22b8b0c65786e3bea1328809bbd/cmd/compose/compose.go#L181)
  - [Not normalizing compose models (when running `config`)](https://github.com/docker/compose/blob/2e7644ff21f9ca0ea6fb5e8d41d4f6af32cd7e20/cmd/compose/convert.go#L69)

### `entrypoint` (optional, run only)

Sets the `--entrypoint` argument when running `docker-compose`.

### `service-ports` (optional, run only)

If set to true, docker compose will run with the service ports enabled and mapped to the host. Equivalent to `--service-ports` in docker-compose.

The default is `false`.

### `upload-container-logs` (optional, run only)

Select when to upload container logs.

- `on-error` Upload logs for all containers when an error occurs
- `always` Always upload logs for all container
- `never` Never upload logs for all container

The default is `on-error`.

### `cli-version` (optional, string or integer)

If set to `2`, plugin will use `docker compose` to execute commands; otherwise it will default to version `1`, using `docker-compose` instead.

### `buildkit` (optional, build only, boolean)

Assuming you have a compatible docker installation and configuration in the agent, activating this option would setup the environment for the `docker-compose build` call to use BuildKit. Note that if you are using `cli-version` 2, you are already using buildkit by default.

You may want to also add `BUILDKIT_INLINE_CACHE=1` to your build arguments (`args` option in this plugin), but know that [there are known issues with it](https://github.com/moby/buildkit/issues/2274).

### `ssh` (optional, build only, boolean or string)

It will add the `--ssh` option to the build command with the passed value (if `true` it will use `default`). Note that it assumes you have a compatible docker installation and configuration in the agent (meaning you are using BuildKit and it is correctly setup).

### `secrets` (optional, build only, array of strings)

All elements in this array will be passed literally to the `build` command as parameters of the [`--secrets` option](https://docs.docker.com/engine/reference/commandline/buildx_build/#secret). Note that you must have BuildKit enabled for this option to have any effect and special `RUN` stanzas in your Dockerfile to actually make use of them.

## Developing

To run the tests:

```bash
docker-compose run --rm tests bats tests tests/v2
```

## License

MIT (see [LICENSE](LICENSE))
