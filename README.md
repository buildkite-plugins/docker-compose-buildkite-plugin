# Docker Compose Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/plugins) allow you to create a build system capable of running any project or tool with a `docker-compose.yml` file in its repository.

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building of images, allowing for fast parallel builds across distributed agents

## Example

The following pipeline will run the `test.sh` command inside a one-off `app` service container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
steps:
  - command: test.sh
    plugins:
      buildkite/docker-compose:
        service: app
```

For a more complete example, the following uses a prebuild step on a dedicated builder agent to build the app service’s image and store it as a build artifact. 25 parallel test jobs are then, each one running the `test.sh` command inside a container built with the pre-built (including any necessary linked containers) across a cluster of agents:

```yml
steps:
  - name: ":docker: Build"
    plugins:
      buildkite/docker-compose:
        build: app
        image-repository: index.docker.io/org/repo
    agents:
      queue: docker-compose-builders
    
  - waiter

  - name: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      buildkite/docker-compose:
        run: app
    agents:
      queue: docker-compose-runners
```

## Options

### `build`

The name of a service to build and store, allowing following pipeline steps to run faster as they won't need to build the image. The step’s `command` will be ignored and does not need to be specified.

### `run`

The name of the service the command should be run within. If the docker-compose command would usually be `docker-compose run app test.sh` then the value would be `app`.

### `config` (optional)

The file name of the Docker Compose configuration file to use.

Default: `docker-compose.yml`

## `image-repository` (optional)

By method for storing the docker images (default is `artifact`).

To use a Docker repository set this to be the repository location you would use for a `docker push`, or example `"index.docker.io/org/repo"`. Each image is tagged to the specific build so you can safely share the same image repository for any number of projects and builds.

Note: this option only needs to be specified on the build step, and will be automatically picked up by following steps.

This option can also be configured on the agent machine using the environment variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_IMAGE_REPOSITORY`.

## Roadmap

* Support pre-building of multiple services

## License

MIT (see [LICENSE](LICENSE))
