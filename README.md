# Docker Compose Buildkite Plugin

__This is designed to run with the upcoming version of 3.0 of Buildkite Agent (currently in beta). Plugins are not yet supported in version 2.1. See the [Containerized Builds with Docker](https://buildkite.com/docs/guides/docker-containerized-builds) guide for running builds in Docker with the current stable version of the Buildkite Agent.__

A Buildkite plugin allowing you to create a build system capable of running any project or tool with a [Docker Compose](https://docs.docker.com/compose/) config file in its repository.

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building of images, allowing for fast parallel builds across distributed agents

## Example

The following pipeline will run `test.sh` inside a `app` service container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose:
        run: app
```

You can also specify a custom Docker Compose config file if you need:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose:
        run: app
        config: docker-compose.tests.yml
```

or multiple config files:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose:
        run: app
        config:
          - docker-compose.yml
          - docker-compose.test.yml
```

# Pre-building the image

To speed up run parallel steps you can add a pre-building step to your pipeline, allowing all the `run` steps to skip image building:

```yml
steps:
  - name: ":docker: Build"
    plugins:
      docker-compose:
        build: app

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      docker-compose:
        run: app
```

If you’re running agents across multiple machines and Docker hosts you’ll want to push the pre-built image to a docker image repository using the `image-repository` option. The following example uses this option, along with dedicated builder and runner agent queues:

```yml
steps:
  - name: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      docker-compose:
        build: app
        image-repository: org/repo
    
  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    agents:
      queue: docker-runner
    plugins:
      docker-compose:
        run: app
```

## Options

### `build`

The name of a service to build and store, allowing following pipeline steps to run faster as they won't need to build the image. The step’s `command` will be ignored and does not need to be specified.

### `run`

The name of the service the command should be run within. If the docker-compose command would usually be `docker-compose run app test.sh` then the value would be `app`.

### `config` (optional)

The file name of the Docker Compose configuration file to use. Can also be a list of filenames.

Default: `docker-compose.yml`

## `image-repository` (optional)

The repository for pushing and pulling pre-built images, same as the repository location you would use for a `docker push`, for example `"org/repo"`. Each image is tagged to the specific build so you can safely share the same image repository for any number of projects and builds.

The default is `""`  which only builds images on the local Docker host doing the build.

Note: this option only needs to be specified on the build step, and will be automatically picked up by following steps.

Only works with version '2' docker-compose.yml configuration files

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY`.

## `tags` (optional)

By default we'll push the image to your `image-repository` tagged with the automatically generated docker compose container name. You can specify your own tags instead:

```
steps:
  - name: ":docker:"
    plugins:
      docker-compose:
        build: app
        image-repository: org/repo
        tags:
          - latest
          - ${BUILDKITE_COMMIT:0:7}
          - $BUILDKITE_BRANCH
          - $BUILDKITE_JOB_ID
```

Note: if you are running multiple agents on a single machine sharing a Docker daemon then it is possible that multiple jobs with the same tags might collide. Docker can't tag and push images as an atomic operation.

## Roadmap

* Support pre-building of multiple Docker Compose services
* Support specifying multiple docker-compose config files

## License

MIT (see [LICENSE](LICENSE))
