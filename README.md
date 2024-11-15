# Docker Compose Buildkite Plugin [![Build status](https://badge.buildkite.com/a1d1805d117ec32791cb22055aedc5ff709f1498024295bef0.svg?branch=master)](https://buildkite.com/buildkite/plugins-docker-compose)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) that lets you build, run and push build steps using [Docker Compose](https://docs.docker.com/compose/).

* Containers are built, run and linked on demand using Docker Compose
* Containers are namespaced to each build job, and cleaned up after use
* Supports pre-building of images, allowing for fast parallel builds across distributed agents
* Supports pushing tagged images to a repository


## Examples

You can learn a lot about how this plugin is used by browsing the [documentation examples](docs/examples.md).

## Configuration

### Main Commands

You will need to specify at least one of the following to use this extension.

#### `build`

The name of a service to build and store, allowing following pipeline steps to run faster as they won't need to build the image. Either a single service or multiple services can be provided as an array.

If you do not specify a `push` option for the same services, the built image(s) will not be available to be used and may cause further steps to fail. If there is no `run` option, the step's `command` will be ignored.

#### `run`

The name of the service the command should be run within. If the docker-compose command would usually be `docker-compose run app test.sh` then the value would be `app`.

#### `push`

A list of services to push.  You can specify just the service name to push or the format `service:registry:tag` to override where the service's image is pushed to. Needless to say, the image for the service must have been built in the very same step or built and pushed previously to ensure it is available for pushing.

:warning: If a service does not have an `image` configuration and no registry/tag are specified in the `push` option, pushing of the service will be skipped by docker.

:warning: The `push` command will fail when the image refers to a remote registry that requires a login and the agent has not been authenticated for it (for example, using the [ecr](https://github.com/buildkite-plugins/ecr-buildkite-plugin) or [docker-login](https://github.com/buildkite-plugins/docker-login-buildkite-plugin) plugins).

### Other options

None of the following are mandatory.

#### `pull` (run only, string or array)

Pull down multiple pre-built images. By default only the service that is being run will be pulled down, but this allows multiple images to be specified to handle prebuilt dependent images. Note that pulling will be skipped if the `skip-pull` option is activated.

#### `run-image` (run only, string)

Set the service image to pull during a run. This can be useful if the image was created outside of the plugin.

#### `collapse-logs` (boolean)

Whether to collapse or expand the log group that is created for the output of the main commands (`run`, `build` and `push`). When this setting is `true`, the output is collected into a `---` group, when `false` the output is collected into a `+++` group. Setting this to `true` can be useful to de-emphasize plugin output if your command creates its own `+++` group.

For more information see [Managing log output](https://buildkite.com/docs/pipelines/managing-log-output).

Default `false`

#### `config`

The file name of the Docker Compose configuration file to use. Can also be a list of filenames. If `$COMPOSE_FILE` is set, it will be used if `config` is not specified.

Default: `docker-compose.yml`

#### `build-alias` (push only, string or array)

Other docker-compose services that should be aliased to the service that was built. This is to have a pre-built image set for different services based off a single definition.

Important: this only works when building a single service, an error will be generated otherwise.

#### `args` (build only, string or array)

A list of KEY=VALUE that are passed through as build arguments when image is being built.

#### `env` or `environment` (run only, string or array)

A list of either KEY or KEY=VALUE that are passed through as environment variables to the container.

#### `env-propagation-list` (run only)

If you set this to `VALUE`, and `VALUE` is an environment variable containing a space-separated list of environment variables such as `A B C D`, then A, B, C, and D will all be propagated to the container. This is helpful when you've set up an `environment` hook to export secrets as environment variables, and you'd also like to programmatically ensure that secrets get propagated to containers, instead of listing them all out.

#### `propagate-environment` (run only, boolean)

Whether or not to automatically propagate all pipeline environment variables into the run container. Avoiding the need to be specified with environment.

**Important**: only pipeline environment variables will be propagated (what you see in the BuildKite UI, those listed in `$BUILDKITE_ENV_FILE`). This does not include variables exported in preceeding `environment` hooks. If you wish for those to be propagated you will need to list them specifically or use `env-propagation-list`.

#### `propagate-aws-auth-tokens` (run only, boolean)

Whether or not to automatically propagate aws authentication environment variables into the docker container. Avoiding the need to be specified with `environment`. This is useful for example if you are using an assume role plugin or you want to pass the role of an agent running in ECS or EKS to the docker container.

Will propagate `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `AWS_STS_REGIONAL_ENDPOINTS`, `AWS_WEB_IDENTITY_TOKEN_FILE`, `AWS_ROLE_ARN`, `AWS_CONTAINER_CREDENTIALS_FULL_URI`, `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`, and `AWS_CONTAINER_AUTHORIZATION_TOKEN`, only if they are set already.

When the `AWS_WEB_IDENTITY_TOKEN_FILE` is specified, it will also mount it automatically for you and make it usable within the container.

#### `command` (run only, array)

Sets the command for the Docker image, and defaults the `shell` option to `false`. Useful if the Docker image has an entrypoint, or doesn't contain a shell.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

#### `shell` (run only, array or boolean)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker-compose run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided a `command`.

Example: `[ "powershell", "-Command" ]`

#### `skip-checkout` (boolean)

Whether to skip the repository checkout phase. This is useful for steps that use a pre-built image and will fail if there is no pre-built image.

**Important**: as the code repository will not be available in the step, you need to ensure that any files used (like the docker compose files or scripts to be executed) are present in some other way (like using artifacts or pre-baked into the images used).

#### `skip-pull` (build and run only, boolean)

Completely avoid running any `pull` command. Images being used will need to be present in the machine from before or have been built in the same step. Could be useful to avoid hitting rate limits when you can be sure the operation is unnecessary. Note that it is possible other commands run in the plugin's lifecycle will trigger a pull of necessary images.

#### `workdir` (run only)

Specify the container working directory via `docker-compose run --workdir`. This option is also used by [`mount-checkout`](#mount-checkout-run-only-string-or-boolean) if it doesn't specify where to mount the checkout in the container.

Example: `/app`

#### `user` (run only)

Run as specified username or uid via `docker-compose run --user`.

#### `propagate-uid-gid` (run only, boolean)

Whether to match the user ID and group ID for the container user to the user ID and group ID for the host user. It is similar to specifying user: 1000:1000, except it avoids hardcoding a particular user/group ID.

Using this option ensures that any files created on shared mounts from within the container will be accessible to the host user. It is otherwise common to accidentally create root-owned files that Buildkite will be unable to remove, since containers by default run as the root user.

#### `mount-ssh-agent` (run only, boolean or string)

Whether to mount the ssh-agent socket (at `/ssh-agent`) from the host agent machine into the container or not. Instead of just `true` or `false`, you can specify absolute path in the container for the home directory of the user used to run on which the agent's `.ssh/known_hosts` will be mounted (by default, `/root`).

Default: `false`

#### `mount-buildkite-agent` (run only, boolean)

Whether to automatically mount the `buildkite-agent` binary and associated environment variables from the host agent machine into the container.

Default: `false`

#### `mount-checkout` (run only, boolean or string)

The absolute path where to mount the current working directory which contains your checked out codebase.

If set to `true` it will mount onto `/workdir`, unless `workdir` is set, in which case that will be used.

Default: `false`

#### `buildkit-inline-cache` (optional, build-only, boolean)

Whether to pass the `BUILDKIT_INLINE_CACHE=1` build arg when building an image. Can be safely used in combination with `args`.

Default: `false`

#### `pull-retries` (run only, integer)

A number of times to retry failed docker pull. Defaults to 0.

#### `push-retries` (push only, integer)

A number of times to retry failed docker push. Defaults to 0.

#### `cache-from` (build only, string or array)

A list of images to attempt pulling before building in the format `service:CACHE-SPEC` to allow for layer re-use. Will be ignored if `no-cache` is turned on.

They will be mapped directly to `cache-from` elements in the build according to the spec so any valid format there should be allowed.

#### `cache-to` (build only, string or array)

A list of export locations to be used to share build cache with future builds in the format `service:CACHE-SPEC` to allow for layer re-use. Unsupported caches are ignored and do not prevent building images.

They will be mapped directly to `cache-to` elements in the build according to the spec so any valid format there should be allowed.

#### `target` (build only)

Allow for intermediate builds as if building with docker's `--target VALUE` options.

Note that there is a single build command run for all services so the target value will apply to all of them.

#### `volumes` (run only, string or array)

A list of volumes to mount into the container. If a matching volume exists in the Docker Compose config file, this option will override that definition.

Additionally, volumes may be specified via the agent environment variable `BUILDKITE_DOCKER_DEFAULT_VOLUMES`, a `;` (semicolon)  delimited list of mounts in the `-v` syntax. (Ex. `buildkite:/buildkite;./app:/app`).

#### `expand-volume-vars` (run only, boolean, unsafe)

When set to true, it will activate interpolation of variables in the elements of the `volumes` configuration array. When turned off (the default), attempting to use variables will fail as the literal `$VARIABLE_NAME` string will be passed to the `-v` option.

:warning: **Important:** this is considered an unsafe option as the most compatible way to achieve this is to run the strings through `eval` which could lead to arbitrary code execution or information leaking if you don't have complete control of the pipeline

Note that rules regarding [environment variable interpolation](https://buildkite.com/docs/pipelines/environment-variables#runtime-variable-interpolation) apply here. That means that `$VARIABLE_NAME` is resolved at pipeline upload time, whereas `$$VARIABLE_NAME` will be at run time. All things being equal, you likely want to use `$$VARIABLE_NAME` on the variables mentioned in this option.

#### `graceful-shutdown` (run only, boolean)

Gracefully shuts down all containers via 'docker-compose stop`.

The default is `false`.

#### `leave-volumes` (run only, boolean)

Prevent the removal of volumes after the command has been run.

The default is `false`.

#### `no-cache` (build and run only, boolean)

Build with `--no-cache`, causing Docker Compose to not use any caches when building the image. This will also avoid creating an override with any `cache-from` entries.

The default is `false`.

#### `build-parallel` (build only, boolean)

Build with `--parallel`, causing Docker Compose to run builds in parallel. Requires docker-compose `1.23+`.

The default is `false`.

#### `tty` (run only, boolean)

If set to true, allocates a TTY. This is useful in some situations TTYs are required.

The default is `false`.

#### `dependencies` (run only, boolean)

If set to false, runs with `--no-deps` and doesn't start linked services.

The default is `true`.

#### `pre-run-dependencies` (run only, boolean)

If `dependencies` are activated (which is the default), you can skip starting them up before the main container by setting this option to `false`. This is useful if you want compose to take care of that on its own at the expense of messier output in the run step.

#### `wait` (run only, boolean)

Whether to wait for dependencies to be up (and healthy if possible) when starting them up. It translates to using [`--wait` in the docker-compose up] command.

Defaults to `false`.

#### `ansi` (run only, boolean)

If set to false, disables the ansi output from containers.

The default is `true`.

#### `use-aliases` (run only, boolean)

If set to true, docker compose will use the service's network aliases in the network(s) the container connects to.

The default is `false`.

#### `verbose` (boolean)

Sets `docker-compose` to run with `--verbose`

The default is `false`.

#### `quiet-pull` (run only, boolean)

Start up dependencies with `--quiet-pull` to prevent even more logs during that portion of the execution.

The default is `false`.

#### `rm` (run only, boolean)

If set to true, docker compose will remove the primary container after run. Equivalent to `--rm` in docker-compose.

The default is `true`.

#### `run-labels` (run only, boolean)

If set to true, adds useful Docker labels to the primary container. See [Container Labels](#container-labels) for more info.

The default is `true`.

#### `build-labels` (build only, string or array)

A list of KEY=VALUE that are passed through as service labels when image is being built. These will be merged with any service labels defined in the compose file.

#### `compatibility` (boolean)

If set to true, all docker compose commands will rum with compatibility mode. Equivalent to `--compatibility` in docker compose.

The default is `false`.

Note that [the effect of this option changes depending on your docker compose CLI version](https://docs.docker.com/compose/cli-command-compatibility/#flags-that-will-not-be-implemented):
* in v1 it translates (composefile) v3 deploy keys to their non-swarm (composefile) v2 equivalents
* in v2 it will revert some behaviour to v1 as well, including (but not limited to):
  - [Character separator for container names](https://github.com/docker/compose/blob/a0acc20d883ce22b8b0c65786e3bea1328809bbd/cmd/compose/compose.go#L181)
  - [Not normalizing compose models (when running `config`)](https://github.com/docker/compose/blob/2e7644ff21f9ca0ea6fb5e8d41d4f6af32cd7e20/cmd/compose/convert.go#L69)

#### `entrypoint` (run only)

Sets the `--entrypoint` argument when running `docker compose`.

#### `require-prebuild` (run only, boolean)

If no prebuilt image is found for the run step, it will cause the plugin to fail the step.

The default is `false`.

#### `service-ports` (run only, boolean)

If set to true, docker compose will run with the service ports enabled and mapped to the host. Equivalent to `--service-ports` in docker-compose.

The default is `false`.

#### `upload-container-logs` (run only)

Select when to upload container logs.

- `on-error` Upload logs for all containers when an error occurs
- `always` Always upload logs for all container
- `never` Never upload logs for all container

The default is `on-error`.

#### `cli-version` (string or integer)

If set to `1`, plugin will use `docker-compose` (that is deprecated and unsupported) to execute commands; otherwise it will default to version `2`, using `docker compose` instead.

#### `buildkit` (build only, boolean)

Assuming you have a compatible docker installation and configuration in the agent, activating this option would setup the environment for the `docker compose build` call to use BuildKit. Note that this should only be necessary if you are using `cli-version` 1 (version 2 already uses buildkit by default).

You may want to also add `BUILDKIT_INLINE_CACHE=1` to your build arguments (`args` option in this plugin), but know that [there are known issues with it](https://github.com/moby/buildkit/issues/2274).

#### `ssh` (build only, boolean or string)

It will add the `--ssh` option to the build command with the passed value (if `true` it will use `default`). Note that it assumes you have a compatible docker installation and configuration in the agent (meaning you are using BuildKit and it is correctly setup).

#### `with-dependencies` (build only, boolean)

If set to true, docker compose will build with the `--with-dependencies` option which will also build dependencies transitively.

The default is `false`.

#### `builder` (object)

Defines the properties required for creating, using and removing Builder Instances. If not set, the default Builder Instance on the Agent Instance will be used.

##### `bootstrap` (boolean)

If set to true, will boot builder instance after creation. Optional when using `create`.

The default is `true`.

##### `create` (boolean)

If set to true, will use `docker buildx create` to create a new Builder Instance using the propeties defined.

The default is `false`.

##### `debug` (boolean)

If set to true, enables debug logging during creation of builder instance. Optional when using `create`.

The default is `false`.

##### `driver`

If set will create a Builder Instance using the selected Driver and use it. Available Drivers:

- `docker-container` creates a dedicated BuildKit container using Docker.
- `kubernetes` creates BuildKit pods in a Kubernetes cluster.
- `remote` connects directly to a manually managed BuildKit daemon.

More details on different [Build Drivers](https://docs.docker.com/build/builders/drivers/).

##### `driver-opt`

Optional, commas separated, Key-Value pairs of driver-specific options to configure the Builder Instance when using `create`. Available options for each Driver:

- [docker-container](https://docs.docker.com/build/builders/drivers/docker-container/)
- [kubernetes](https://docs.docker.com/build/builders/drivers/kubernetes/)
- [remote](https://docs.docker.com/build/builders/drivers/remote/)

Example: `memory=100m`

##### `name`

Sets the name of the Builder instance to create or use. Required when using `create` or `use` builder paramaters.

##### `platform`

Commas separated, fixed platforms for builder instance. Optional when using `create`.

Example: `linux/amd64,linux/arm64`

##### `remote-address`

Address of remote builder instance. Required when using `driver: remote`.

Example: `tcp://localhost:1234`

##### `remove` (boolean)

If set to true will stop and remove the Builder Instance specified by `name`.

The default is `false`.

##### `use` (boolean)

If set to true will use Builder Instance specified by `name`.

The default is `false`.

## Developing

To run the tests:

```bash
docker compose run --rm tests bats tests tests/v1
```

## License

MIT (see [LICENSE](LICENSE))
