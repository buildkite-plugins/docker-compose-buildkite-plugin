# Examples

This is a collection of snippets showing some common use-cases for the plugin and its caveats.

### Simple run

The following pipeline will run `test.sh` inside a `app` service container using Docker Compose, the equivalent to running `docker-compose run app test.sh`:

```yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v5.8.0:
          run: app
```

:warning: Warning: you should not use this plugin with an array of commands at the step level. Execute a script in your repository, a single command separated by `;` or the plugin's [`command` option](#command-run-only-array) instead:

```yml
steps:
  - plugins:
      - docker-compose#v5.8.0:
          run: app
          command: ["custom", "command", "values"]
```

The plugin will honor the value of the `COMPOSE_FILE` environment variable if one exists (for example, at the pipeline or step level). But you can also specify custom Docker Compose config files with the `config` option:

```yml
steps:
  - command: test.sh
    plugins:
      - docker-compose#v5.8.0:
          run: app
          config: docker-compose.tests.yml
          env:
            - BUILDKITE_BUILD_NUMBER
```

### Authenticated registries

You can leverage the [docker-login plugin](https://github.com/buildkite-plugins/docker-login-buildkite-plugin) in tandem for authenticating with a registry. For example, the following will build and push an image to a private repo, and pull from that private repo in subsequent run commands:

```yml
steps:
  - plugins:
      - docker-login#v2.0.1:
          username: xyz
      - docker-compose#v5.8.0:
          build: app
          push: app:index.docker.io/myorg/myrepo:tag
  - wait
  - command: test.sh
    plugins:
      - docker-login#v2.0.1:
          username: xyz
      - docker-compose#v5.8.0:
          run: app
```

Note, you will need to add the configuration to all steps in which you use this plugin.

### Artifacts

If you’re generating artifacts in the build step, you’ll need to ensure your Docker Compose configuration volume mounts the host machine directory into the container where those artifacts are created.

For example, if your `app` service generates information that you want as artifacts in the `/folder/dist` folder, you would need to ensure the `app` service in your Docker Compose config has a host volume mount defined as `./dist:/folder/dist` or specify it in the plugin's configuration:

```yml
steps:
  - command: generate-dist.sh
    artifact_paths: "dist/*"
    plugins:
      - docker-compose#v5.8.0:
          run: app
          volumes:
            - "./dist:/folder/dist"
```

If you want to use environment variables in the `volumes` element, you will need to activate the (unsafe) option `expand-volume-vars` (and most likely escape it using `$$VARIABLE_NAME` to ensure they are not interpolated when the pipeline is uploaded).

### Environment

By default, docker-compose makes whatever environment variables it gets available for
interpolation of docker-compose.yml, but it doesn't pass them in to your containers.

You can use the [environment key in docker-compose.yml](https://docs.docker.com/compose/environment-variables/) to either set specific environment vars or "pass through" environment variables from outside docker-compose.

#### Specific values

If you want to add extra environment above what is declared in your `docker-compose.yml`,
this plugin offers a `environment` block of its own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      - docker-compose#v5.8.0:
          run: app
          env:
            - BUILDKITE_BUILD_NUMBER
            - BUILDKITE_PULL_REQUEST
            - MY_CUSTOM_ENV=llamas
```

Note how the values in the list can either be just a key (so the value is sourced from the environment) or a KEY=VALUE pair.

#### Pipeline variables

Alternatively, you can have the plugin add all environment variables defined for the job by the agent as defined in [`BUILDKITE_ENV_FILE`](https://buildkite.com/docs/pipelines/environment-variables#BUILDKITE_ENV_FILE) activating the `propagate-environment` option:

```yml
steps:
  - command: use-vars.sh
    plugins:
      - docker-compose#v5.8.0:
          run: app
          propagate-environment: true
```

### Profiles

You can take advantage of [Compose profiles](https://docs.docker.com/compose/profiles/) defined in your compose file by setting the appropriate environment variable in the step. For example:

```yaml
steps:
  - key: test
    command: echo 'from inside the container'
    env:
      COMPOSE_PROFILES: "frontend,debug"
    plugins:
      - docker-compose#v5.8.0:
          run: app
```

It is important to understand that, as documented in the official documentation, profiles may prevent some service dependencies from being started up unless the compose file is setup correctly which may cause unforseen issues with your steps when used.

### Container Labels

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

### Build Arguments

You can use the [build args key in docker-compose.yml](https://docs.docker.com/compose/compose-file/build/#args) to set specific build arguments when building an image.

Alternatively, if you want to set build arguments when pre-building an image, this plugin offers an `args` block of its own:

```yml
steps:
  - command: generate-dist.sh
    plugins:
      - docker-compose#v5.8.0:
          build: app
          args:
            - MY_CUSTOM_ARG=panda
          push: app
```

Note that the values in the list must be a `KEY=VALUE` pair.

### Pre-building the image

If you have multiple steps that use the same service/image (such as steps that run in parallel), you can use this plugin in a specific `build` step to your pipeline. That will set specific metadata in the pipeline for this plugin to use in `run` steps afterwards:

```yml
steps:
  - label: ":docker: Build"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app

  - wait

  - label: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      - docker-compose#v5.8.0:
          run: app
          require-prebuild: true
```

All `run` steps for the service `app` will automatically pull and use the pre-built image. Note that, for the example to work as-is, the `app` service needs to have an `image` element defined or the build/push step needs to be changed to `push: app:the_registry:the_tag` (and the agent running all the steps need to be authenticated against the registry if required).

Note that the `require-prebuild` option means that if no prebuilt image is found, all `Test %n` jobs will fail. Without it, if the agent the `Test %n` is running on has ever built such an image and has it appropriately tagged it may still run.

### Building multiple images

Sometimes your compose file has multiple services that need building. The example below will build images for the `app` and `tests` service and then the run step will pull them down and use them for the run as needed.

```yml
steps:
  - label: ":docker: Build"
    agents:
      queue: docker-builder
    plugins:
      - docker-compose#v5.8.0:
          build:
            - app
            - tests
          push:
            - app
            - tests

  - wait

  - label: ":docker: Test %n"
    command: test.sh
    parallelism: 25
    plugins:
      - docker-compose#v5.8.0:
          run: tests
```

### Pushing Tagged Images

If you want to push your Docker images ready for deployment, you can use the `push` configuration (which operates similar to [docker-compose push](https://docs.docker.com/compose/reference/push/):

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v5.8.0:
          push: app
```

To push multiple images, you can use a list:

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v5.8.0:
          push:
            - first-service
            - second-service
```

If you want to push to a specific location (that's not defined as the `image` in your docker-compose.yml), you can use the `{service}:{repo}:{tag}` format, for example:

```yml
steps:
  - label: ":docker: Push"
    plugins:
      - docker-compose#v5.8.0:
          push:
            - app:index.docker.io/myorg/myrepo/myapp
            - app:index.docker.io/myorg/myrepo/myapp:latest
```

### Reusing caches from images

A newly spawned agent won't contain any of the docker caches for the first run which will result in a long build step. To mitigate this you can reuse caches from a previously built image (if it was pushed from a previous build):

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app:index.docker.io/myorg/myrepo:my-branch
          cache-from:
            - "app:myregistry:port/myrepo/myapp:my-branch"
            - "app:myregistry:port/myrepo/myapp:latest"

  - wait

  - label: ":docker: Push to final repository"
    plugins:
      - docker-compose#v5.8.0:
          push:
            - app:myregistry:port/myrepo/myapp:latest
```

For images to be pulled and used as a cache they [need to be built with the `BUILDKIT_INLINE_CACHE=1` build argument](https://docs.docker.com/engine/reference/commandline/build/#cache-from).

The values you add in the `cache-from` will be mapped to the corresponding service's configuration. That means that you can use any valid cache type your environment supports:

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app:index.docker.io/myorg/myrepo:my-branch
          cache-from:
            - "app:type=registry,ref=myregistry:port/myrepo/myapp:my-branch"
            - "app:myregistry:port/myrepo/myapp:latest"

  - wait

  - label: ":docker: Push to final repository"
    plugins:
      - docker-compose#v5.8.0:
          push:
            - app:myregistry:port/myrepo/myapp:latest
```

### Create, Use and Remove Builder Instances

#### Create

Most Docker setups, unless configured, will use the `docker` Builder Driver by default. More details on it [here](https://docs.docker.com/build/builders/drivers/docker/).

The `docker` driver can handle most situations but for advance features with the Docker, different Builder Drivers are required and this requires a Builder Instance being created first, which can be done manually or with the Plugin. To create a Builder Instance using a chosen Driver, requires the `name`, `driver` and `create` parameters:

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app:index.docker.io/myorg/myrepo:my-branch
          cache-from:
            - "app:myregistry:port/myrepo/myapp:my-branch"
            - "app:myregistry:port/myrepo/myapp:latest"
          builder:
            name: container
            driver: docker-container
            create: true
```

**If a Builder Instance with the same `name` already exists, it will not be recreated.**

#### Use

By default, Builder Instances specified by `name` or that are created with `create` are not used, and the default Builder Instance on the Agent will be used. To use a Builder Instance, requires the `name` and `use` parameters and the Builder Instance to exist:

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app:index.docker.io/myorg/myrepo:my-branch
          cache-from:
            - "app:myregistry:port/myrepo/myapp:my-branch"
            - "app:myregistry:port/myrepo/myapp:latest"
          builder:
            name: container
            use: true
```

#### Remove

By default, Builder Instances specified by `name` or that are created with `create` are not removed after the Job finishs. To remove a Builder Instance, requires the `name` and `remove` parameters and the Builder Instance to exist:

```yaml
steps:
  - label: ":docker: Build an image"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app:index.docker.io/myorg/myrepo:my-branch
          cache-from:
            - "app:myregistry:port/myrepo/myapp:my-branch"
            - "app:myregistry:port/myrepo/myapp:latest"
          builder:
            name: container
            driver: docker-container
            create: true
            use: true
            remove: true
```

**Removing a Builder Instance by default will remove the daemon running it and its state (which can be used for cache).**
**To keep the daemon or state, use the `keep-daemon` or `keep-state` parameters.**
**These parameter are only applicable with specific Drivers, for detail see [`docker buildx rm`](https://docs.docker.com/reference/cli/docker/buildx/rm/).**

### Reusing caches from remote registries

A newly spawned agent won't contain any of the docker caches for the first run which will result in a long build step. To mitigate this you can reuse caches from a remote registry, but requires pushing cache and manifests to a registry using a Builder Driver that supports cache exports e.g., `docker-container` - the `docker` driver does not support this by default. For any remote registry used that requires authenication, see [Authenticated registries](#authenticated-registries) for more details. This requires use of the `cache-from`, `cache-to`, `name` and `use` parameters but will use the `create` and `driver` parameters to create the Builder Instance across multiple Agents:

```yaml
steps:
  - label: ":docker: Build an image and push cache"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          push: app:${DOCKER_REGISTRY}/${IMAGE_REPO}:cache
          cache-from:
            - "app:type=registry,ref=${DOCKER_REGISTRY}/${IMAGE_REPO}:cache"
          cache-to:
            - "app:type=registry,mode=max,image-manifest=true,oci-mediatypes=true,ref=${DOCKER_REGISTRY}/${IMAGE_REPO}:cache"
          builder:
            name: container
            use: true
            create: true
            driver: docker-container

  - wait

  - label: ":docker: Build an image using remote cache"
    plugins:
      - docker-compose#v5.8.0:
          build: app
          cache-from:
            - "app:type=registry,ref=${DOCKER_REGISTRY}/${IMAGE_REPO}:cache"
          builder:
            name: container
            use: true
            create: true
            driver: docker-container
```

The first Step will build the Image using a Builder Instance with the `docker-container` driver and push the image cache to the remote registry, as specified by `cache-to`, with additional cache export options being used to export all the layers of intermediate steps with the image manifests. More details cache export options [here](https://github.com/moby/buildkit?tab=readme-ov-file#registry-push-image-and-cache-separately).

The second Step will build the Image using a Builder Instance with the `docker-container` driver and use remote registry for the image cache, as specified by `cache-from`, speeding up Image building process.
