# Docker Compose Buildkite Plugin ![Build status](https://badge.buildkite.com/d8fd3a4fef8419a6a3ebea79739a09ebc91106538193f99fce.svg?branch=master)

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
      docker-compose#v2.5.1:
        run: app
```

You can also specify a custom Docker Compose config file and what environment to pass
through if you need:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose#v2.5.1:
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
      docker-compose#v2.5.1:
        run: app
        config:
          - docker-compose.yml
          - docker-compose.test.yml
```

You can leverage the [docker-login plugin](https://github.com/buildkite-plugins/docker-login-buildkite-plugin) in tandem for authenticating with a registry. For example, the following will build and push an image to a private repo, and pull from that private repo in subsequent run commands:

```yml
steps:
  - plugins:
      docker-login#v2.0.1:
        username: xyz
      docker-compose#v2.5.1:
        build: app
        image-repository: index.docker.io/myorg/myrepo
  - wait
  - command: test.sh
    plugins:
      docker-login#v2.0.1:
        username: xyz
      docker-compose#v2.5.1:
        run: app
```

## Artifacts

If you’re generating artifacts in the build step, you’ll need to ensure your Docker Compose configuration volume mounts the host machine directory into the container where those artifacts are created.

For example, if you had the following step:

```yml
steps:
  - command: generate-dist.sh
    artifact_paths: "dist/*"
    plugins:
      docker-compose#v2.5.1:
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
      docker-compose#v2.5.1:
        run: app
        volumes:
          - "./dist:/app/dist"
```

## Environment

By default, docker-compose makes whatever environment variables it gets available for
interpolation of docker-compose.yml, but it doesn't pass them in to your containers.

You can use the [environment key in docker-compose.yml](https://docs.docker.com/compose/environment-variables/) to either set specific environment vars or "pass through" environment
variables from outside docker-compose.

If you want to add extra environment above what is declared in your `docker-compose.yml`,
this plugin offers a `environment` block of it's own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      docker-compose#v2.5.1:
        run: app
        env:
          - BUILDKITE_BUILD_NUMBER
          - BUILDKITE_PULL_REQUEST
          - MY_CUSTOM_ENV=llamas
```

Note how the values in the list can either be just a key (so the value is sourced from the environment) or a KEY=VALUE pair.

## Build Arguments

You can use the [build args key in docker-compose.yml](https://docs.docker.com/compose/compose-file/#args) to set specific build arguments when building an image.

Alternatively, if you want to set build arguments when pre-building an image, this plugin offers an `args` block of it's own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      docker-compose#v2.5.1:
        build: app
        args:
          - MY_CUSTOM_ARG=panda
```

Note that the values in the list must be a KEY=VALUE pair.

## Pre-building the image

To speed up run parallel steps you can add a pre-building step to your pipeline, allowing all the `run` steps to skip image building:

```yml
steps:
  - name: ":docker: Build"
    plugins:
      docker-compose#v2.5.1:
        build: app

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      docker-compose#v2.5.1:
        run: app
```

If you’re running agents across multiple machines and Docker hosts you’ll want to push the pre-built image to a docker image repository using the `image-repository` option. The following example uses this option, along with dedicated builder and runner agent queues:

```yml
steps:
  - name: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      docker-compose#v2.5.1:
        build: app
        image-repository: index.docker.io/myorg/myrepo

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    agents:
      queue: docker-runner
    plugins:
      docker-compose#v2.5.1:
        run: app
```

## Building multiple images

Sometimes your compose file has multiple services that need building. The example below will build images for the `app` and `tests` service and then the run step will pull them down and use them for the run as needed.

```yml
steps:
  - name: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      docker-compose#v2.5.1:
        build:
          - app
          - tests
        image-repository: index.docker.io/myorg/myrepo

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      docker-compose#v2.5.1:
        run: tests
```

## Pushing Tagged Images

If you want to push your Docker images ready for deployment, you can use the `push` configuration (which operates similar to [docker-compose push](https://docs.docker.com/compose/reference/push/):

```yml
steps:
  - name: ":docker: Push"
    plugins:
      docker-compose#v2.5.1:
        push: app
```

If you need to authenticate to the repository to push (e.g. when pushing to Docker Hub), use the Docker Login plugin:

```yml
steps:
  - name: ":docker: Push"
    plugins:
      docker-login#v2.0.1:
        username: xyz
      docker-compose#v2.5.1:
        push: app
```

To push multiple images, you can use a list:

```yml
steps:
  - name: ":docker: Push"
    plugins:
      docker-login#v2.0.1:
        username: xyz
      docker-compose#v2.5.1:
        push:
          - first-service
          - second-service
```

If you want to push to a specific location (that's not defined as the `image` in your docker-compose.yml), you can use the `{service}:{repo}:{tag}` format, for example:

```yml
steps:
  - name: ":docker: Push"
    plugins:
      docker-login#v2.0.1:
        username: xyz
      docker-compose#v2.5.1:
        push:
        - app:index.docker.io/myorg/myrepo/myapp
        - app:index.docker.io/myorg/myrepo/myapp:latest
```

## Reusing caches from images

A newly spawned agent won't contain any of the docker caches for the first run which will result in a long build step. To mitigate this you can reuse caches from a previously built image (if it was pushed from a previous build):

```yaml
steps:
  - name: ":docker Build an image"
    plugins:
      docker-compose#v2.5.1:
        build: app
        image-repository: index.docker.io/myorg/myrepo
        cache-from: app:index.docker.io/myorg/myrepo/myapp:latest
  - name: ":docker: Push to final repository"
    plugins:
      docker-compose#v2.5.1:
        push:
        - app:index.docker.io/myorg/myrepo/myapp
        - app:index.docker.io/myorg/myrepo/myapp:latest
```

## Configuration

### `build`

The name of a service to build and store, allowing following pipeline steps to run faster as they won't need to build the image. The step’s `command` will be ignored and does not need to be specified.

Either a single service or multiple services can be provided as an array.

### `run`

The name of the service the command should be run within. If the docker-compose command would usually be `docker-compose run app test.sh` then the value would be `app`.

### `push`

A list of services to push in the format `service:image:tag`. If an image has been pre-built with the build step, that image will be re-tagged, otherwise docker-compose's built in push operation will be used.

### `pull` (optional, run only)

Pull down multiple pre-built images. By default only the service that is being run will be pulled down, but this allows multiple images to be specified to handle prebuilt dependent images.

### `config` (optional)

The file name of the Docker Compose configuration file to use. Can also be a list of filenames.

Default: `docker-compose.yml`

### `image-repository` (optional, build only)

The repository for pushing and pulling pre-built images, same as the repository location you would use for a `docker push`, for example `"index.docker.io/myorg/myrepo"`. Each image is tagged to the specific build so you can safely share the same image repository for any number of projects and builds.

The default is `""` which only builds images on the local Docker host doing the build.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY`.

### `image-name` (optional, build only)

The name to use when tagging pre-built images. If multiple images are built in the build phase, you must provide an array of image names.

Note: this option can only be specified on a `build` step.

### `args` (optional, build only)

A list of KEY=VALUE that are passed through as build arguments when image is being built.

### `env` or `environment` (optional, run only)

A list of either KEY or KEY=VALUE that are passed through as environment variables to the container.

### `workdir` (optional, run only)

Specify the container working directory via `docker-compose run --workdir`.

### `pull-retries` (optional)

A number of times to retry failed docker pull. Defaults to 0.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_PULL_RETRIES`.

### `push-retries` (optional)

A number of times to retry failed docker push. Defaults to 0.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_PUSH_RETRIES`.

### `cache-from` (optional)

A list of images to pull caches from in the format `service:index.docker.io/myorg/myrepo/myapp:tag` before building. Requires docker-compose file version `3.2+`. Currently only one image per service is supported. If there's no image present for a service local docker cache will be used.

Note: this option can only be specified on a `build` step.

### `volumes` (optional, run only)

A list of volumes to mount into the container. If a matching volume exists in the Docker Compose config file, this option will override that definition.

Additionally, volumes may be specified via the agent environment variable `BUILDKITE_DOCKER_DEFAULT_VOLUMES`, a `;` (semicolon)  delimited list of mounts in the `-v` syntax. (Ex. `buildkite:/buildkite;./app:/app`).

### `leave-volumes` (optional, run only)

Prevent the removal of volumes after the command has been run.

The default is `false`.

### `no-cache` (optional, build only)

Sets the build step to run with `--no-cache`, causing Docker Compose to not use any caches when building the image.

The default is `false`.

### `tty` (optional, run only)

If set to false, doesn't allocate a TTY. This is useful in some situations where TTY's aren't supported, for instance windows.

The default is `true`.

### `dependencies` (optional, run only)

If set to false, doesn't start linked services.

The default is `true`.

### `ansi` (optional, run only)

If set to false, disables the ansi output from containers.

The default is `true`.

### `verbose` (optional)

Sets `docker-compose` to run with `--verbose`

The default is `false`.

## Developing

To run the tests:

```bash
docker-compose run --rm tests
```

## License

MIT (see [LICENSE](LICENSE))
