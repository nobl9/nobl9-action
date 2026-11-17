#!/usr/bin/env bats

setup() {
  bats_require_minimum_version 1.7.0
  bats_load_library bats-support
  bats_load_library bats-assert
  export GITHUB_REPOSITORY=nobl9/nobl9-action APP_SLUG=release-test
  export SLOCTL_TAG=v0.27.0 SLOCTL_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa SOURCE_RUN_ID=456
  export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
  export FAKE_STATE="$BATS_TEST_TMPDIR/state" FAKE_REMOTE="$BATS_TEST_TMPDIR/remote"
  export PATH="$BATS_TEST_DIRNAME/helpers:$PATH"
  script="$BATS_TEST_DIRNAME/../.github/scripts/update-sloctl.sh"
  mkdir -p "$FAKE_STATE"
  printf '[{"tag_name":"v0.3.0","draft":false,"prerelease":false}]\n' >"$FAKE_STATE/releases"
  git init --quiet --bare --initial-branch=main "$FAKE_REMOTE"
  git clone --quiet "$FAKE_REMOTE" "$BATS_TEST_TMPDIR/seed"
  cd "$BATS_TEST_TMPDIR/seed"
  printf 'FROM docker.io/nobl9/sloctl:0.26.0 AS sloctl\n\nFROM alpine:3.24.1\n' >Dockerfile
  printf '# Action\n\nuses: nobl9/nobl9-action@v0.3.0\nuses: nobl9/nobl9-action@v0.3.0\n' >README.md
  git add .
  git commit --quiet -m Initial
  git tag v0.3.0
  git push --quiet origin main --tags
  fresh_checkout
}

@test "a successful sloctl release updates the action and publishes the next patch" {
  run bash "$script"
  assert_success
  assert_equal "$(jq -r 'last.tag_name' "$FAKE_STATE/releases")" v0.3.1
  assert_equal "$(git --git-dir="$FAKE_REMOTE" show v0.3.1:Dockerfile | head -n 1)" \
    "FROM docker.io/nobl9/sloctl:0.27.0 AS sloctl"
  assert_equal "$(git --git-dir="$FAKE_REMOTE" show v0.3.1:README.md)" \
    $'# Action\n\nuses: nobl9/nobl9-action@v0.3.1\nuses: nobl9/nobl9-action@v0.3.1'
  assert_equal "$(git --git-dir="$FAKE_REMOTE" rev-parse v0.3.1)" \
    "$(git --git-dir="$FAKE_REMOTE" rev-parse main)"
}

@test "replaying a published release does not create another action version" {
  run bash "$script"
  assert_success
  fresh_checkout
  run bash "$script"
  assert_success
  assert_output --partial "Action v0.3.1 already bundles v0.27.0."
  assert_equal "$(jq length "$FAKE_STATE/releases")" 2
}

@test "a failed source release cannot create an action pull request" {
  export SOURCE_CONCLUSION=failure
  run bash "$script"
  assert_failure
  assert_output --partial "not a successful official sloctl release"
  refute [ -f "$FAKE_STATE/pr" ]
}

@test "a moved sloctl tag cannot create an action pull request" {
  export SOURCE_TAG_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  run bash "$script"
  assert_failure
  assert_output --partial "no longer matches the release SHA"
  refute [ -f "$FAKE_STATE/pr" ]
}

@test "a prerelease input is rejected before GitHub writes" {
  export SLOCTL_TAG=v0.27.0-rc.1
  run bash "$script"
  assert_failure
  assert_output --partial "Invalid sloctl release tag."
  refute [ -f "$FAKE_STATE/pr" ]
}

@test "an older sloctl release does not downgrade main" {
  export SLOCTL_TAG=v0.25.0
  run bash "$script"
  assert_success
  assert_output --partial "main already bundles sloctl 0.26.0"
  refute [ -f "$FAKE_STATE/pr" ]
}

@test "a GitHub read failure does not become a missing release" {
  export LATEST_READ_FAILURE=true
  run bash "$script"
  assert_failure
  refute [ -f "$FAKE_STATE/pr" ]
  assert_equal "$(jq length "$FAKE_STATE/releases")" 1
}

@test "failed pull request checks prevent merge and publication" {
  export PR_CHECK_FAILURE=true
  run bash "$script"
  assert_failure
  refute [ -f "$FAKE_STATE/merged" ]
  assert_equal "$(jq length "$FAKE_STATE/releases")" 1
}

@test "pending pull request checks are awaited before merging" {
  export PR_PENDING=true
  run bash "$script"
  assert_success
  assert [ -f "$FAKE_STATE/watched-pr" ]
  assert_equal "$(jq -r 'last.tag_name' "$FAKE_STATE/releases")" v0.3.1
}

@test "a skipped end-to-end check prevents merge and publication" {
  export E2E_STATE=SKIPPING
  run bash "$script"
  assert_failure
  assert_output --partial "All three action checks must succeed"
  refute [ -f "$FAKE_STATE/merged" ]
}

@test "a failed merge leaves the release unpublished and can be retried" {
  export MERGE_FAILURE=true
  run bash "$script"
  assert_failure
  assert_equal "$(jq length "$FAKE_STATE/releases")" 1
  unset MERGE_FAILURE
  fresh_checkout
  run bash "$script"
  assert_success
  assert_equal "$(jq -r 'last.tag_name' "$FAKE_STATE/releases")" v0.3.1
}

@test "failed main checks prevent tag creation and publication" {
  export MAIN_CONCLUSION=failure
  run bash "$script"
  assert_failure
  refute git --git-dir="$FAKE_REMOTE" show-ref --verify --quiet refs/tags/v0.3.1
  assert_equal "$(jq length "$FAKE_STATE/releases")" 1
}

@test "publication resumes after a tag was created but release creation failed" {
  export RELEASE_FAILURE=true
  run bash "$script"
  assert_failure
  assert git --git-dir="$FAKE_REMOTE" show-ref --verify --quiet refs/tags/v0.3.1
  unset RELEASE_FAILURE
  fresh_checkout
  run bash "$script"
  assert_success
  assert_equal "$(jq -r 'last.tag_name' "$FAKE_STATE/releases")" v0.3.1
}

@test "a conflicting action tag is never overwritten" {
  git --git-dir="$FAKE_REMOTE" update-ref refs/tags/v0.3.1 refs/tags/v0.3.0
  run bash "$script"
  assert_failure
  assert_output --partial "already points to another commit"
  assert_equal "$(git --git-dir="$FAKE_REMOTE" rev-parse v0.3.1)" \
    "$(git --git-dir="$FAKE_REMOTE" rev-parse v0.3.0)"
  assert_equal "$(jq length "$FAKE_STATE/releases")" 1
}

@test "publication resumes at the existing tag when main has advanced" {
  export RELEASE_FAILURE=true
  run bash "$script"
  assert_failure
  tagged_sha="$(git --git-dir="$FAKE_REMOTE" rev-parse v0.3.1)"
  fresh_checkout
  printf 'A later documentation change.\n' >later.txt
  git add later.txt
  git commit --quiet -m Later
  git push --quiet origin main
  unset RELEASE_FAILURE
  fresh_checkout
  run bash "$script"
  assert_success
  assert_equal "$(git --git-dir="$FAKE_REMOTE" rev-parse v0.3.1)" "$tagged_sha"
  assert_equal "$(jq -r 'last.tag_name' "$FAKE_STATE/releases")" v0.3.1
}

@test "unexpected changes on an existing automation branch are rejected" {
  export MERGE_FAILURE=true
  run bash "$script"
  assert_failure
  printf 'RUN unexpected-command\n' >>Dockerfile
  git add Dockerfile
  git commit --quiet -m Unexpected
  git push --quiet origin "sloctl-$SLOCTL_TAG"
  unset MERGE_FAILURE
  fresh_checkout
  run bash "$script"
  assert_failure
  assert_output --partial "unexpected changes to Dockerfile"
  refute [ -f "$FAKE_STATE/merged" ]
}

@test "a newer sloctl release cannot replace an unfinished action publication" {
  export RELEASE_FAILURE=true
  run bash "$script"
  assert_failure
  pending_sha="$(git --git-dir="$FAKE_REMOTE" rev-parse main)"
  unset RELEASE_FAILURE
  export SLOCTL_TAG=v0.28.0 SLOCTL_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb SOURCE_RUN_ID=457
  fresh_checkout
  run bash "$script"
  assert_failure
  assert_output --partial "Publish pending action v0.3.1 for v0.27.0 before updating to v0.28.0."
  assert_equal "$(git --git-dir="$FAKE_REMOTE" rev-parse main)" "$pending_sha"

  export SLOCTL_TAG=v0.27.0 SLOCTL_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa SOURCE_RUN_ID=456
  fresh_checkout
  run bash "$script"
  assert_success
  export SLOCTL_TAG=v0.28.0 SLOCTL_SHA=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb SOURCE_RUN_ID=457
  fresh_checkout
  run bash "$script"
  assert_success
  assert_equal "$(jq -r 'last.tag_name' "$FAKE_STATE/releases")" v0.3.2
}

fresh_checkout() {
  local checkout
  checkout="$(mktemp -d "$BATS_TEST_TMPDIR/checkout.XXXXXX")"
  git clone --quiet "$FAKE_REMOTE" "$checkout"
  cd "$checkout"
}
