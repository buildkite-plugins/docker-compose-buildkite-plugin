# Docker Compose Buildkite Plugin [![Build status](https://badge.buildkite.com/a1d1805d117ec32791cb22055aedc5ff709f1498024295bef0.svg?branch=master)](https://buildkite.com/buildkite/plugins-docker-compose)

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
      - docker-compose#v3.12.0:
          run: app
```

:warning: Warning: you should not use this plugin with an array of commands at the step level. Execute a script in your repository, a single command separated by `;` or the plugin's [`command` option](#command-optional-run-only-array) instead.

You can also specify a custom Docker Compose config file and what environment to pass
through if you need:

```yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
          run: app
```

If you want to control how your command is passed to docker-compose, you can use the command parameter on the plugin directly:

```yml
steps:
  - plugins:
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
  - wait
  - command: test.sh
    plugins:
      - docker-login#v2.0.1:
          username: xyz
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
          run: app
          volumes:
            - "./dist:/app/dist"
```

If you want to use environment variables in the `volumes` element, you will need to activate the (unsafe) option `expand-volume-vars`.

## Environment

By default, docker-compose makes whatever environment variables it gets available for
interpolation of docker-compose.yml, but it doesn't pass them in to your containers.

You can use the [environment key in docker-compose.yml](https://docs.docker.com/compose/environment-variables/) to either set specific environment vars or "pass through" environment
variables from outside docker-compose.

If you want to add extra environment above what is declared in your `docker-compose.yml`,
this plugin offers a `environment` block of its own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      - docker-compose#v3.12.0:
          run: app
          env:
            - BUILDKITE_BUILD_NUMBER
            - BUILDKITE_PULL_REQUEST
            - MY_CUSTOM_ENV=llamas
```

Note how the values in the list can either be just a key (so the value is sourced from the environment) or a KEY=VALUE pair.

## Build Arguments

You can use the [build args key in docker-compose.yml](https://docs.docker.com/compose/compose-file/#args) to set specific build arguments when building an image.

Alternatively, if you want to set build arguments when pre-building an image, this plugin offers an `args` block of its own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo

  - wait

  - label: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
          build:
            - app
            - tests
          image-repository: index.docker.io/myorg/myrepo

  - wait

  - label: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      - docker-compose#v3.12.0:
          run: tests
```

## Pushing Tagged Images

If you want to push your Docker images ready for deployment, you can use the `push` configuration (which operates similar to [docker-compose push](https://docs.docker.com/compose/reference/push/):

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v3.12.0:
          push: app
```

To push multiple images, you can use a list:

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v3.12.0:
          push:
            - first-service
            - second-service
```

If you want to push to a specific location (that's not defined as the `image` in your docker-compose.yml), you can use the `{service}:{repo}:{tag}` format, for example:

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v3.12.0:
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
      - docker-compose#v3.12.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
          cache-from: app:index.docker.io/myorg/myrepo/myapp:latest
  - wait
  - label: ":docker: Push to final repository"
    plugins:
      - docker-compose#v3.12.0:
          push:
            - app:index.docker.io/myorg/myrepo/myapp
            - app:index.docker.io/myorg/myrepo/myapp:latest
```

#### Multiple cache-from values

This plugin allows for the value of `cache-from` to be a string or a list. If it's a list, as below, then the first successfully pulled image will be used.

```yaml
steps:
  - label: ":docker Build an image"
    plugins:
      - docker-compose#v3.12.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
          cache-from:
            - app:index.docker.io/myorg/myrepo/myapp:my-branch
            - app:index.docker.io/myorg/myrepo/myapp:latest
  - wait
  - label: ":docker: Push to final repository"
    plugins:
      - docker-compose#v3.12.0:
          push:
            - app:index.docker.io/myorg/myrepo/myapp
            - app:index.docker.io/myorg/myrepo/myapp:my-branch
            - app:index.docker.io/myorg/myrepo/myapp:latest
```

You may actually want to build your image with multiple cache-from values, for instance, with the cached images of multiple stages in a multi-stage build.
Adding a grouping tag to the end of a cache-from list item allows this plugin to differentiate between groups within which only the first successfully downloaded image should be used (those elements that don't have a group specified will make a separate `:default:` group of its own). This way, not all images need to be downloaded and used as cache, not just the first.

```yaml
steps:
  - label: ":docker: Build Intermediate Image"
    plugins:
      - docker-compose#v3.12.0:
          build: myservice_intermediate  # docker-compose.yml is the same as myservice but has `target: intermediate`
          image-name: buildkite-build-${BUILDKITE_BUILD_NUMBER}
          image-repository: index.docker.io/myorg/myrepo/myservice_intermediate
          cache-from:
            - myservice_intermediate:index.docker.io/myorg/myrepo/myservice_intermediate:${BUILDKITE_BRANCH}
            - myservice_intermediate:index.docker.io/myorg/myrepo/myservice_intermediate:latest
  - wait
  - label: ":docker: Build Final Image"
    plugins:
      - docker-compose#v3.12.0:
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

## Reusing previously built images

If an build image has already been built previously, you can skip it if it
already exists on the repository.

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v3.8.0:
          build: app
          image-repository: index.docker.io/myorg/myrepo
          cache-from: app:index.docker.io/myorg/myrepo/myapp:123
          use-prior-image: true
```

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
      - docker-compose#v3.12.0:
          run: myservice
          push: myservice
```

Will cause the image to be built twice (once before running and once before pushing) unless there was a previous `build` step that set the appropriate metadata.

##### Run & Push

A basic pipeline similar to the following:

```yaml
steps:
  - label: ":docker: Build & Push"
    plugins:
      - docker-compose#v3.12.0:
          build: myservice
          push: myservice
```

Will cause the image to be pushed twice (once by the build step and another by the push step)

### `pull` (optional, run only)

Pull down multiple pre-built images. By default only the service that is being run will be pulled down, but this allows multiple images to be specified to handle prebuilt dependent images.

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

### `command` (optional, run only, array)

Sets the command for the Docker image, and defaults the `shell` option to `false`. Useful if the Docker image has an entrypoint, or doesn't contain a shell.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

### `shell` (optional, run only, array or boolean)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker-compose run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided a `command`.

Example: `[ "powershell", "-Command" ]`

### `skip-checkout` (optional, run only)

Whether to skip the repository checkout phase. This is useful for steps that use a pre-built image. This will fail if there is no pre-built image.

### `workdir` (optional, run only)

Specify the container working directory via `docker-compose run --workdir`.

### `user` (optional, run only)

Run as specified username or uid via `docker-compose run --user`.

### `propagate-uid-gid` (optional, run-only, boolean)

Whether to match the user ID and group ID for the container user to the user ID and group ID for the host user. It is similar to specifying user: 1000:1000, except it avoids hardcoding a particular user/group ID.

Using this option ensures that any files created on shared mounts from within the container will be accessible to the host user. It is otherwise common to accidentally create root-owned files that Buildkite will be unable to remove, since containers by default run as the root user.

### `mount-ssh-agent` (optional, run-only, boolean)

Whether to automatically mount the ssh-agent socket from the host agent machine into the container (at `/ssh-agent`and `/root/.ssh/known_hosts` respectively), allowing git operations to work correctly.

Default: `false`

### `mount-buildkite-agent` (optional, run-only, boolean)

Whether to automatically mount the `buildkite-agent` binary and associated environment variables from the host agent machine into the container.

Default: `false`

### `pull-retries` (optional)

A number of times to retry failed docker pull. Defaults to 0.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_RETRIES`.

### `push-retries` (optional)

A number of times to retry failed docker push. Defaults to 0.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_RETRIES`.

### `cache-from` (optional, build only)

A list of images to pull caches from in the format `service:index.docker.io/myorg/myrepo/myapp:tag` before building, ignoring any failures. If multiple images are listed for a service, the first one to successfully pull will be used. Requires docker-compose file version `3.2+`.

### `use-prior-image` (optional, build only)

When true, the build step will be skipped if the `cache-from` image exists on
the remote repository. The run will use the existing image in later steps.

### `volumes` (optional, run only)

A list of volumes to mount into the container. If a matching volume exists in the Docker Compose config file, this option will override that definition.

Additionally, volumes may be specified via the agent environment variable `BUILDKITE_DOCKER_DEFAULT_VOLUMES`, a `;` (semicolon)  delimited list of mounts in the `-v` syntax. (Ex. `buildkite:/buildkite;./app:/app`).

### `expand-volume-vars` (optional, boolean, run only, unsafe)

When set to true, it will activate interpolation of variables in the elements of the `volumes` configuration array. When turned off (the default), attempting to use variables will fail as the literal `$VARIABLE_NAME` string will be passed to the `-v` option.

:warning: **Important:** this is considered an unsafe option as the most compatible way to achieve this is to run the strings through `eval` which could lead to arbitrary code execution or information leaking if you don't have complete control of the pipeline

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

If set to false, doesn't start linked services.

The default is `true`.

### `ansi` (optional, run only)

If set to false, disables the ansi output from containers.

The default is `true`.

### `use-aliases` (optional, run only)

If set to true, docker compose will use the service's network aliases in the network(s) the container connects to.

The default is `false`.

### `verbose` (optional)

Sets `docker-compose` to run with `--verbose`

The default is `false`.

### `rm` (optional, run only)

If set to true, docker compose will remove the primary container after run. Equivalent to `--rm` in docker-compose.

The default is `true`.

### `entrypoint` (optional, run only)

Sets the `--entrypoint` argument when running `docker-compose`.

### `upload-container-logs` (optional, run only)

Select when to upload container logs.

- `on-error` Upload logs for all containers when an error occurs
- `always` Always upload logs for all container
- `never` Never upload logs for all container

The default is `on-error`.

### `cli-version` (optional)

If set to `2`, plugin will use `docker compose` to execute commands; otherwise it will default to version `1` using `docker-compose` instead.

## Developing

To run the tests:

```bash
docker-compose run --rm tests bats tests tests/v2
```

## License

MIT (see [LICENSE](LICENSE))
