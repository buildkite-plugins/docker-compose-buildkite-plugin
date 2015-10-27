# Docker Compose Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/plugins) to run any CI step in isolated Docker containers using Docker Compose, giving you a build system capable of running any project or tool as long as it has a `docker-compose.yml` file in its repository.

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building and pushing of images to a private registry, for fast parallel builds across distributed agents

## Example

The following is an example Docker Compose build pipeline which builds the app container first, pushes to a private registry, and then runs 25 parallel test jobs in isolated containers (including any necessary linked containers):

```yml
steps:
  - agents:
      queue: docker-builder
    plugins:
      toolmantim/docker-compose:
        - build-and-push: app
    
  - waiter

  - command: test.sh
    parallelism: 25
    agents:
      queue: docker-compose
    plugins:
      toolmantim/docker-compose:
        - container: app
```

## Options

### `container`

The name of the container the command should be run within.

### `build-and-push`

This steps builds the image, pushes it to a registry, and stores that image name as build meta-data, speeding up all following steps in the build pipeline that use that same service (regardless of which machine they run on)>

```yml
steps:
  - name: "Pre-build"
  - plugins:
      toolmantim/docker-compose:
        build-and-push: app
```

This step assumes you have private registry credentials are already configured on the build agent.
