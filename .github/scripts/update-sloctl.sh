#!/usr/bin/env bash

set -euo pipefail

readonly state_file=.github/sloctl-release.json
readonly stable_version='(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
readonly expected_checks='["Lint and build (ubuntu-24.04)","Lint and build (ubuntu-24.04-arm)","End-to-end test"]'

fail() {
  echo "$*" >&2
  exit 1
}

gh_read() {
  local attempt result status
  for attempt in {1..3}; do
    status=0
    result="$(timeout 15s gh "$@")" || status=$?
    if ((status == 0)); then
      printf '%s\n' "$result"
      return
    fi
    echo "GitHub read failed (attempt ${attempt}/3, exit ${status})." >&2
    if ((attempt == 3)); then
      return "$status"
    fi
    sleep 2
  done
}

validate_source() {
  [[ "${SLOCTL_TAG:-}" =~ ^v${stable_version}$ ]] || fail "Invalid sloctl release tag."
  [[ "${SLOCTL_SHA:-}" =~ ^[0-9a-f]{40}$ ]] || fail "Invalid sloctl release SHA."
  [[ "${SOURCE_RUN_ID:-}" =~ ^[1-9][0-9]*$ ]] || fail "Invalid source release run ID."
  [[ "${GITHUB_REPOSITORY:-}" == nobl9/nobl9-action ]] || fail "Unexpected action repository."

  gh_read api "repos/nobl9/sloctl/actions/runs/${SOURCE_RUN_ID}" |
    jq -e --arg tag "$SLOCTL_TAG" --arg sha "$SLOCTL_SHA" '
      .name == "Release" and .path == ".github/workflows/release.yml" and
      .event == "push" and .status == "completed" and .conclusion == "success" and
      .head_branch == $tag and .head_sha == $sha and
      .head_repository.full_name == "nobl9/sloctl"
    ' >/dev/null || fail "The source run is not a successful official sloctl release."
  gh_read api "repos/nobl9/sloctl/releases/tags/${SLOCTL_TAG}" |
    jq -e --arg tag "$SLOCTL_TAG" '
      .tag_name == $tag and .draft == false and .prerelease == false
    ' >/dev/null || fail "The sloctl release is not published as a stable release."
  local tag_sha
  tag_sha="$(gh_read api "repos/nobl9/sloctl/commits/${SLOCTL_TAG}" --jq .sha)"
  [[ "$tag_sha" == "$SLOCTL_SHA" ]] || fail "The sloctl tag no longer matches the release SHA."
}

image_version() {
  local dockerfile
  dockerfile="$(git show "$1:Dockerfile")"
  if [[ "$dockerfile" =~ ^FROM\ docker.io/nobl9/sloctl:(${stable_version})\ AS\ sloctl$'\n' ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    fail "Expected one stable sloctl image pin at the start of Dockerfile."
  fi
}

next_patch() {
  local major minor patch
  [[ "$1" =~ ^v${stable_version}$ ]] || fail "Invalid action release tag: $1"
  IFS=. read -r major minor patch <<<"${1#v}"
  printf 'v%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
}

write_update() {
  local base="$1" action_tag="$2" previous_tag="$3" directory="$4"
  mkdir -p "$directory/.github"
  git show "${base}:Dockerfile" |
    sed -E "1s|^FROM docker.io/nobl9/sloctl:[0-9.]+ AS sloctl$|FROM docker.io/nobl9/sloctl:${SLOCTL_TAG#v} AS sloctl|" >"$directory/Dockerfile"
  git show "${base}:README.md" |
    sed -E "s|nobl9/nobl9-action@v[0-9]+\.[0-9]+\.[0-9]+|nobl9/nobl9-action@${action_tag}|g" >"$directory/README.md"
  jq -n --arg tag "$SLOCTL_TAG" --arg sha "$SLOCTL_SHA" --arg run "$SOURCE_RUN_ID" \
    --arg action "$action_tag" --arg previous "$previous_tag" \
    '{sloctl_tag: $tag, sloctl_sha: $sha, source_run_id: $run,
      action_tag: $action, previous_action_tag: $previous}' >"$directory/$state_file"
}

read_pr_checks() {
  gh_read pr view "$1" --json statusCheckRollup --jq '
    .statusCheckRollup | map({name: (.name // .context),
      state: (.conclusion // .state // .status)})
  '
}

wait_for_pr_checks() {
  local pr="$1" checks="" attempt
  for attempt in {1..60}; do
    if checks="$(read_pr_checks "$pr")" &&
      jq -e --argjson expected "$expected_checks" \
        '([$expected[]] - [.[] | .name]) | length == 0' <<<"$checks" >/dev/null; then
      break
    fi
    sleep 2
  done
  jq -e --argjson expected "$expected_checks" \
    '([$expected[]] - [.[] | .name]) | length == 0' <<<"$checks" >/dev/null ||
    fail "The pull request does not have all three action checks."
  timeout 18m gh pr checks "$pr" --watch --fail-fast --interval 10 ||
    fail "Pull request checks did not pass."
  read_pr_checks "$pr" |
    jq -e --argjson expected "$expected_checks" '
      [.[] | select(.state == "SUCCESS") | .name] as $passed |
      ($expected - $passed) | length == 0
    ' >/dev/null || fail "All three action checks must succeed before merging."
}

prepare_pull_request() {
  local previous_tag="$1" action_tag="$2" branch="sloctl-${SLOCTL_TAG}"
  local remote_branch base changed file pr head_sha merge_result
  remote_branch="$(git ls-remote --heads origin "refs/heads/${branch}")"
  if [[ -n "$remote_branch" ]]; then
    git fetch origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
    base="$(git merge-base origin/main "origin/${branch}")"
    changed="$(git diff --name-only "$base" "origin/${branch}")"
    while IFS= read -r file; do
      case "$file" in
      Dockerfile | README.md | "$state_file") ;;
      *) fail "Unexpected file on the automation branch: $file" ;;
      esac
    done <<<"$changed"
    write_update "$base" "$action_tag" "$previous_tag" "$scratch/expected"
    for file in Dockerfile README.md "$state_file"; do
      git show "origin/${branch}:${file}" >"$scratch/actual"
      cmp -s "$scratch/expected/$file" "$scratch/actual" ||
        fail "The automation branch contains unexpected changes to $file."
    done
    git switch -c "$branch" "origin/${branch}"
    git merge --no-edit origin/main
  else
    git switch -c "$branch" origin/main
  fi

  write_update origin/main "$action_tag" "$previous_tag" "$scratch/update"
  for file in Dockerfile README.md "$state_file"; do
    mkdir -p "$(dirname "$file")"
    cp "$scratch/update/$file" "$file"
  done
  git add -- Dockerfile README.md "$state_file"
  # A new commit also retries checks after a previous attempt failed.
  git commit --allow-empty -m "chore: bundle sloctl ${SLOCTL_TAG} for action ${action_tag}"
  git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin "$branch"
  pr="$(gh_read pr list --base main --head "$branch" --state open --json number --jq '.[0].number // empty')"
  if [[ -z "$pr" ]]; then
    printf '## Motivation\n\nPublish an action release for sloctl %s.\n\n## Summary\n\nUpdated the bundled image and README examples for action %s.\n\nSource release: https://github.com/nobl9/sloctl/releases/tag/%s\n' \
      "$SLOCTL_TAG" "$action_tag" "$SLOCTL_TAG" >"$scratch/pr-body.md"
    timeout 30s gh pr create --base main --head "$branch" \
      --title "chore: bundle sloctl ${SLOCTL_TAG}" --body-file "$scratch/pr-body.md"
    pr="$(gh_read pr list --base main --head "$branch" --state open --json number --jq '.[0].number // empty')"
  fi
  [[ "$pr" =~ ^[1-9][0-9]*$ ]] || fail "Could not find the automation pull request."
  wait_for_pr_checks "$pr"
  git fetch origin main
  git merge-base --is-ancestor origin/main HEAD ||
    fail "main changed during checks. Rerun the update to include those changes."
  head_sha="$(git rev-parse HEAD)"
  # The App must satisfy repository protection. The merge is pinned to the checked commit.
  merge_result="$(timeout 30s gh api --method PUT "repos/${GITHUB_REPOSITORY}/pulls/${pr}/merge" \
    -f merge_method=squash -f "sha=${head_sha}")"
  publication_sha="$(jq -er 'select(.merged == true) | .sha' <<<"$merge_result")"
  [[ "$publication_sha" =~ ^[0-9a-f]{40}$ ]] || fail "The pull request was not merged."
}

wait_for_main_checks() {
  local run_id="" attempt run_state
  for attempt in {1..60}; do
    run_id="$(gh_read run list --workflow checks.yml --event push --branch main \
      --commit "$publication_sha" --limit 20 --json databaseId --jq 'sort_by(.databaseId) | last | .databaseId // empty')"
    [[ -z "$run_id" ]] || break
    sleep 2
  done
  [[ "$run_id" =~ ^[1-9][0-9]*$ ]] || fail "Could not find main checks for ${publication_sha}."
  run_state="$(gh_read run view "$run_id" --json status,conclusion)"
  if jq -e '.status == "completed" and .conclusion != "success"' <<<"$run_state" >/dev/null; then
    timeout 30s gh run rerun "$run_id" --failed
  fi
  timeout 18m gh run watch "$run_id" --exit-status --interval 10 ||
    fail "Main checks did not succeed."
  gh_read run view "$run_id" --json jobs |
    jq -e --argjson expected "$expected_checks" '
      [.jobs[] | select(.conclusion == "success") | .name] as $passed |
      ($expected - $passed) | length == 0
    ' >/dev/null || fail "All three main checks must succeed before publication."
}

tag_commit() {
  local action_tag="$1" matching_tag
  matching_tag="$(gh_read api "repos/${GITHUB_REPOSITORY}/git/matching-refs/tags/${action_tag}" \
    --jq ".[] | select(.ref == \"refs/tags/${action_tag}\") | .ref")"
  if [[ -n "$matching_tag" ]]; then
    gh_read api "repos/${GITHUB_REPOSITORY}/commits/${action_tag}" --jq .sha
  fi
}

release_record() {
  gh_read api --paginate "repos/${GITHUB_REPOSITORY}/releases" \
    --jq ".[] | select(.tag_name == \"$1\")"
}

publish_release() {
  local action_tag="$1" previous_tag="$2" tag_sha existing_release latest_tag
  latest_tag="$(gh_read api "repos/${GITHUB_REPOSITORY}/releases/latest" --jq .tag_name)"
  [[ "$latest_tag" == "$previous_tag" || "$latest_tag" == "$action_tag" ]] ||
    fail "Another action release was published. Reconcile the pending action version before retrying."
  tag_sha="$(tag_commit "$action_tag")"
  if [[ -n "$tag_sha" ]]; then
    [[ "$tag_sha" == "$publication_sha" ]] || fail "Action tag ${action_tag} already points to another commit."
  else
    timeout 30s gh api --method POST "repos/${GITHUB_REPOSITORY}/git/refs" \
      -f "ref=refs/tags/${action_tag}" -f "sha=${publication_sha}" >/dev/null
  fi
  existing_release="$(release_record "$action_tag")"
  if [[ -n "$existing_release" ]]; then
    jq -e '.draft == false and .prerelease == false' <<<"$existing_release" >/dev/null ||
      fail "Action release ${action_tag} already exists as a draft or prerelease."
    echo "Action release ${action_tag} is already published."
    return
  fi
  printf 'Updated bundled sloctl to [%s](https://github.com/nobl9/sloctl/releases/tag/%s).\n' \
    "$SLOCTL_TAG" "$SLOCTL_TAG" >"$scratch/release-notes.md"
  timeout 30s gh release create "$action_tag" --verify-tag --target "$publication_sha" \
    --title "$action_tag" --generate-notes --notes-start-tag "$previous_tag" \
    --notes-file "$scratch/release-notes.md"
}

main() {
  validate_source
  [[ -z "$(git status --porcelain)" ]] || fail "The checkout must be clean."
  scratch="$(mktemp -d)"
  trap 'rm -rf -- "$scratch"' EXIT
  git fetch origin main --tags
  local current_version latest_tag released_version state action_tag previous_tag bot_id tagged_sha tagged_state
  local pending_tag pending_source pending_release
  current_version="$(image_version origin/main)"
  if [[ "$(printf '%s\n' "$current_version" "${SLOCTL_TAG#v}" | sort -V | tail -n 1)" != "${SLOCTL_TAG#v}" ]]; then
    echo "Skipping ${SLOCTL_TAG}: main already bundles sloctl ${current_version}."
    return
  fi
  latest_tag="$(gh_read api "repos/${GITHUB_REPOSITORY}/releases/latest" --jq .tag_name)"
  action_tag="$(next_patch "$latest_tag")"
  released_version="$(image_version "$latest_tag")"
  if git cat-file -e "origin/main:${state_file}" 2>/dev/null; then
    state="$(git show "origin/main:${state_file}")"
    if [[ "$(jq -r .sloctl_tag <<<"$state")" == "$SLOCTL_TAG" ]]; then
      [[ "$(jq -r .sloctl_sha <<<"$state")" == "$SLOCTL_SHA" ]] ||
        fail "The previously synchronized sloctl tag has a different SHA."
    fi
  else
    state='{}'
  fi
  pending_tag="$(jq -r '.action_tag // empty' <<<"$state")"
  pending_source="$(jq -r '.sloctl_tag // empty' <<<"$state")"
  if [[ -n "$pending_tag" && "$pending_source" != "$SLOCTL_TAG" ]]; then
    [[ "$pending_tag" =~ ^v${stable_version}$ ]] || fail "Invalid pending action version."
    pending_release="$(release_record "$pending_tag")"
    if [[ -z "$pending_release" ]] ||
      ! jq -e '.draft == false and .prerelease == false' <<<"$pending_release" >/dev/null; then
      fail "Publish pending action ${pending_tag} for ${pending_source} before updating to ${SLOCTL_TAG}."
    fi
  fi
  if [[ "$released_version" == "${SLOCTL_TAG#v}" ]]; then
    echo "Action ${latest_tag} already bundles ${SLOCTL_TAG}."
    return
  fi
  if [[ "$(jq -r .sloctl_tag <<<"$state")" == "$SLOCTL_TAG" ]]; then
    action_tag="$(jq -er .action_tag <<<"$state")"
    previous_tag="$(jq -er .previous_action_tag <<<"$state")"
    [[ "$action_tag" == "$(next_patch "$previous_tag")" ]] || fail "Invalid pending action version."
    publication_sha="$(git rev-parse origin/main)"
    tagged_sha="$(tag_commit "$action_tag")"
    if [[ -n "$tagged_sha" ]]; then
      git merge-base --is-ancestor "$tagged_sha" origin/main ||
        fail "The pending action tag is not part of main."
      tagged_state="$(git show "${tagged_sha}:${state_file}")"
      [[ "$(jq -Sc . <<<"$tagged_state")" == "$(jq -Sc . <<<"$state")" ]] ||
        fail "The pending action tag contains a different release record."
      publication_sha="$tagged_sha"
    fi
  else
    previous_tag="$latest_tag"
    bot_id="$(gh_read api "users/${APP_SLUG}[bot]" --jq .id)"
    git config user.name "${APP_SLUG}[bot]"
    git config user.email "${bot_id}+${APP_SLUG}[bot]@users.noreply.github.com"
    prepare_pull_request "$previous_tag" "$action_tag"
  fi
  wait_for_main_checks
  publish_release "$action_tag" "$previous_tag"
}

main "$@"
