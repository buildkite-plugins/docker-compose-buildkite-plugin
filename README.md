# Docker Compose Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/plugins) allow you to create a build system capable of running any project or tool with a `docker-compose.yml` file in its repository.

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building of images, allowing for fast parallel builds across distributed agents

## Example

The following pipeline will run the `test.sh` command inside a one-off `app` service container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
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

One or more services to build and store, allowing following pipeline steps to run faster as they won't need to build the image.

### `run`

The name of the service the command should be run within.

For example, if the docker-compose command would usually be `docker-compose run app test.sh` then the `run` value would be `app`.

### `compose-config`

The name of the Docker Compose configuration file to use.

Default: `docker-compose.yml`

## Roadmap

* Add a `build-storage` option that allows you to change it from `artifact` (current option) to `registry`, which does a docker push/pull instead of artifact upload/download.

## License

MIT (see [LICENSE](LICENSE))
