# Upgrading to v5

Version 5.0.0 of this plugin introduced a lot of backwards-incompatible changes. This should help you review and provide you with actionable steps for you to upgrade.

## Summary

This is an overview of behaviour changes that may break your existing pipelines.

* CLI v2 is now the default
* usage of buildkit is turned on by default
* `run` and `push` steps will not do a build if there is no image
* `build` steps will not push the image
* `image-registry` and `image-name` are no longer necessary
* pipeline meta-data used to share pre-built image information is set on `push` instead of `build`
* TTY allocation is turned off by default when running
* `collapse-run-log-groups` is now `collapse-logs` and applies to all stages (run, push and build)
* `cache-from` now is of the form: `SERVICE:CACHE_FROM_SPEC` and supports any cache type and specification supported by your underlying docker engine
* elements in `cache-from` will not be pulled, docker compose's cache will pull what/if necessary (inline cache is needed on images pushed)
* `separator-cache-from` is no longer necessary
* tags (if present) on `cache-from` or `push` options are no longer validated
* a service that has an `image` configuration will take precedence over pre-built image metadata

Other minor fixes
* `target` option implementation has been fixed
* compose override files will only be created when:
   - `target` option is used on `build` steps
   - `cache-from` option is used on `build` steps
   - a pre-built image is found on `push` or `run` steps
* when steps finish, override files will be deleted

## `cache-from` (and `separator-cache-from`)

The only accepted format now for this configuration is `<SERVICE_NAME>:<CACHE_SPEC>`. This means that you need to review the values if you:

* used groups
* used the `separator-cache-from` option
* depend heavily on images being pulled for building

This simplification means that all caching is now reliant on [docker's underlying `cache-from` implementation](https://docs.docker.com/engine/reference/commandline/build/#cache-from). Values can be any accepted format on that option which should provide with a lot more flexibility and resiliency.

### Troubleshooting

The plugin should print out the override file used in the step's logs for you to review and try to duplicate the behaviour in your local docker environment.

As per the documentation, the images you want to use as cache must have been built with the `BUILDKIT_INLINE_CACHE=1` build argument. Otherwise, the manifest used by docker to determine if the image contains layers that could be useful to pull will not be present and will not be used.

Note that docker silently ignores any `cache-from` configuration that is not valid or can not be used.

## `image-repository` and/or `image-name`

These options were used to push images in `build` steps.

You need to:
* delete these options
* add a `push` or `run` on the very same step
* combine them into a single entry in the format `repository:tag`


Example change:
```diff
-    - docker-compose#v4.16.0:
+    - docker-compose#v5.0.0:
         build: base
-        image-name: image-name-build_id
-        image-repository: image-repo-host/builds
         push:
+        - image-repo-host/builds:image-name-build_id
```

## `cli-version`

If you were using this option to ensure that `docker compose` was used, you should be able to remove it safely. On the other hand, if your build environment only has the old v1 CLI interface (`docker-compose`), you will need to make some changes.

**IMPORTANT**: Compose V1 has been [deprecated since July 2023](https://docs.docker.com/compose/migrate/), please consider upgrading.

The easiest way to make the change would be to add an environment hook in your agent that defines the variable `BUILDKITE_PLUGIN_DOCKER_COMPOSE_CLI_VERSION=1`. This way, not only you will not need to make any changes to all your pipelines, but also you can test out the same pipelines when you are ready to upgrade to agents that do have CLI v2 available with no further changes.

Alternatively, you can add the same variable definition to your pipeline as a global environment variable instead of adding the option to each and every step.

## `collapse-run-log-groups`

Just rename the option to `collapse-logs`
