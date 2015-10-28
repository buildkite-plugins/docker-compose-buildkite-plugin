# Docker Compose Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/plugins) to run any CI step in isolated Docker containers using Docker Compose, giving you a build system capable of running any project or tool as long as it has a `docker-compose.yml` file in its repository.

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports using pre-built images created with [docker-compose-prebuilder plugin](https://github.com/toolmantim/docker-compose-prebuilder-buildkite-plugin), allowing for fast parallel builds across distributed agents

## Example

The following pipeline will run the `test.sh` command inside the `app` container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
  - command: test.sh
    plugins:
      toolmantim/docker-compose:
        command-container: app
```

For a more complete example, the following uses the prebuild plugin to build the image on a dedicated builder agent, store the docker image as a build artifact, and then run 25 parallel test jobs in isolated containers (including any necessary linked containers) across a cluster of agents using that docker image:

```yml
steps:
  - agents:
      queue: docker-compose-prebuilder
    plugins:
      toolmantim/docker-compose-prebuilder:
        prebuild-container: app
    
  - waiter

  - command: test.sh
    parallelism: 25
    agents:
      queue: docker-compose
    plugins:
      toolmantim/docker-compose:
        command-container: app
```

## Options

### `command-container` (required)

The name of the container the command should be run within.

For example, if the docker-compose command would usually be `docker-compose run app test.sh` then the `command-container` would be `app`.

### `compose-config`

The name of the Docker Compose configuration file to use.

Default: `docker-compose.yml`

## Related plugins

* [docker-compose-prebuilder](https://github.com/toolmantim/docker-compose-prebuilder-buildkite-plugin)

## License

MIT (see [LICENSE](LICENSE))
