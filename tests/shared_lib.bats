#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
load '../lib/shared.bash'

@test "expand_var works" {
  export MY_VAR="llamas"
  MY_STRING="foo:bar:\$MY_VAR"

  run expand_var "$MY_STRING"

  assert_success
  assert_output "foo:bar:llamas"
}

@test "expand_var works via envsubst" {
  export MY_VAR="llamas"
  MY_STRING="foo:bar:\$MY_VAR"

  ENVSUB_STUB_STDIN="$BATS_TEST_TMPDIR/envsubst_input"
  stub envsubst  "cat > '$ENVSUB_STUB_STDIN'; echo 'foo:bar:llamas'"

  run expand_var_with_envsubst "$MY_STRING"

  assert_success
  assert_output "foo:bar:llamas"

  run cat "$ENVSUB_STUB_STDIN"

  assert_success
  assert_output "$MY_STRING"

  unstub envsubst
}

@test "expand_var works via envsubst with an allowlist" {
  export MY_VAR="llamas"
  MY_STRING="foo:bar:\$MY_VAR"
  ALLOWLIST='$MY_VAR'
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_EXPAND_VARS_ALLOWLIST="$ALLOWLIST"

  ENVSUB_STUB_STDIN="$BATS_TEST_TMPDIR/envsubst_input"
  stub envsubst  "'$ALLOWLIST' : cat > '$ENVSUB_STUB_STDIN'; echo 'foo:bar:llamas'"

  run expand_var_with_envsubst "$MY_STRING"

  assert_success
  assert_output "foo:bar:llamas"

  run cat "$ENVSUB_STUB_STDIN"

  assert_success
  assert_output "$MY_STRING"

  unstub envsubst
}

@test "expand_var works via envsubst with an allowlist not including the var" {
  export MY_VAR="llamas"
  export MY_OTHER_VAR="more_llamas"
  MY_STRING="foo:bar:\$MY_VAR:\$MY_OTHER_VAR"
  ALLOWLIST='$MY_OTHER_VAR'
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_EXPAND_VARS_ALLOWLIST="$ALLOWLIST"

  ENVSUB_STUB_STDIN="$BATS_TEST_TMPDIR/envsubst_input"
  stub envsubst  "'$ALLOWLIST' : cat > '$ENVSUB_STUB_STDIN'; echo 'foo:bar:\$MY_VAR:more_llamas'"

  run expand_var_with_envsubst "$MY_STRING"

  assert_success
  assert_output "foo:bar:\$MY_VAR:more_llamas"

  run cat "$ENVSUB_STUB_STDIN"

  assert_success
  assert_output "$MY_STRING"

  unstub envsubst
}

@test "expand_var works via eval" {
  export MY_VAR="llamas"
  MY_STRING="foo:bar:\$MY_VAR"

  run expand_var_with_eval "$MY_STRING"

  assert_success
  assert_output "foo:bar:llamas"
}
