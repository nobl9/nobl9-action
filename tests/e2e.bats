setup() {
  bats_require_minimum_version 1.7.0
  bats_load_library bats-support
  bats_load_library bats-assert

  export INPUT_CLIENT_ID="${SLOCTL_CLIENT_ID:-}"
  export INPUT_CLIENT_SECRET="${SLOCTL_CLIENT_SECRET:-}"

  printf -v test_project 'action-e2e-%(%Y%m%d%H%M%S)T-%s-%s' -1 "$RANDOM" "$RANDOM"
  sed "s/name: action-e2e/name: ${test_project}/" \
    "${BATS_TEST_DIRNAME}/fixtures/project.yaml" >"${BATS_TEST_TMPDIR}/project.yaml"
  cd "$BATS_TEST_TMPDIR"
}

teardown() {
  if [[ ${cleanup_required:-false} == true ]]; then
    run_sloctl delete project "$test_project"
    assert_success
    run_sloctl get project "$test_project"
    assert_success
    assert_output 'No resources found.'
  fi
}

# bats test_tags=e2e
@test "action applies and deletes a project" {
  run_sloctl get project "$test_project"
  assert_success
  assert_output 'No resources found.'
  cleanup_required=true

  run_action apply
  assert_success
  run_sloctl get project "$test_project" --output json
  assert_success
  assert_equal "$(jq -r '.[0].metadata.name' <<<"$output")" "$test_project"

  run_action delete
  assert_success
  run_sloctl get project "$test_project"
  assert_success
  assert_output 'No resources found.'
  cleanup_required=false
}

run_action() {
  # Check action inputs without sloctl credential environment overrides.
  run env -u SLOCTL_CLIENT_ID -u SLOCTL_CLIENT_SECRET \
    INPUT_SLOCTL_YML=project.yaml INPUT_OPERATION="$1" INPUT_DRY_RUN=false \
    /entrypoint.sh
}

run_sloctl() {
  run sloctl --no-config-file "$@"
}
