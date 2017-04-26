# Docker Compose Buildkite Plugin

__This is designed to run with the upcoming version of 3.0 of Buildkite Agent (currently in beta). Plugins are not yet supported in version 2.1. See the [Containerized Builds with Docker](https://buildkite.com/docs/guides/docker-containerized-builds) guide for running builds in Docker with the current stable version of the Buildkite Agent.__

A [Buildkite](https://buildkite.com/) plugin allowing you to create a build system capable of running any project or tool with a [Docker Compose](https://docs.docker.com/compose/) config file in its repository.

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building of images, allowing for fast parallel builds across distributed agents

## Example

The following pipeline will run `test.sh` inside a `app` service container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose#v1.2.0:
        run: app
```

You can also specify a custom Docker Compose config file if you need:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose#v1.2.0:
        run: app
        config: docker-compose.tests.yml
```

or multiple config files:

```yml
steps:
  - command: test.sh
    plugins:
      docker-compose#v1.2.0:
        run: app
        config:
          - docker-compose.yml
          - docker-compose.test.yml
```

# Artifacts

If you’re generating artifacts in the build step, you’ll need to ensure your Docker Compose configuration volume mounts the host machine directory into the container where those artifacts are created.

For example, if you had the following step:

```yml
steps:
  - command: generate-dist.sh
    artifact_paths: "dist/*"
    plugins:
      docker-compose#v1.2.0:
        run: app
```

Assuming your application’s directory inside the container was `/app`, you would need to ensure your `app` service in your Docker Compose config has the following host volume mount:

```yml
volumes:
  - "./dist:/app/dist"
```

# Pre-building the image

To speed up run parallel steps you can add a pre-building step to your pipeline, allowing all the `run` steps to skip image building:

```yml
steps:
  - name: ":docker: Build"
    plugins:
      docker-compose#v1.2.0:
        build: app

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      docker-compose#v1.2.0:
        run: app
```

If you’re running agents across multiple machines and Docker hosts you’ll want to push the pre-built image to a docker image repository using the `image-repository` option. The following example uses this option, along with dedicated builder and runner agent queues:

```yml
steps:
  - name: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      docker-compose#v1.2.0:
        build: app
        image-repository: index.docker.io/org/repo

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    agents:
      queue: docker-runner
    plugins:
      docker-compose#v1.2.0:
        run: app
```

# Building multiple images

Sometimes your compose file has multiple services that need building. The example below will build images for the `app` and `tests` service and then the run step will pull them down and use them for the run as needed.

```yml
steps:
  - name: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      docker-compose#v1.2.0:
        build: 
          - app
          - tests
        image-repository: index.docker.io/org/repo

  - wait

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      docker-compose#v1.2.0:
        run: tests
```

## Options

### `build`

The name of a service to build and store, allowing following pipeline steps to run faster as they won't need to build the image. The step’s `command` will be ignored and does not need to be specified.

Either a single service or multiple services can be provided as an array.

### `run`

The name of the service the command should be run within. If the docker-compose command would usually be `docker-compose run app test.sh` then the value would be `app`.

### `config` (optional)

The file name of the Docker Compose configuration file to use. Can also be a list of filenames.

Default: `docker-compose.yml`

## `image-repository` (optional)

The repository for pushing and pulling pre-built images, same as the repository location you would use for a `docker push`, for example `"index.docker.io/org/repo"`. Each image is tagged to the specific build so you can safely share the same image repository for any number of projects and builds.

The default is `""`  which only builds images on the local Docker host doing the build.

Note: this option only needs to be specified on the build step, and will be automatically picked up by following steps.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY`.

## `image-name` (optional)

The name to use when tagging pre-built images.

The default is `${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD}-build-${BUILDKITE_BUILD_NUMBER}`, for example `my-project-web-build-42`.

Note: this option can only be specified on a `build` step.

## License

MIT (see [LICENSE](LICENSE))
