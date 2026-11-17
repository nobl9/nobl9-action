# Development

Run the commands below from the repository root.

The Dockerfile copies `sloctl` from the official [`nobl9/sloctl` image](https://hub.docker.com/r/nobl9/sloctl).
The Alpine runtime supplies Bash and CA certificates.
Docker images and GitHub Actions use version tags.
Renovate updates these dependencies except for the sloctl image, which the release workflow updates.

Install [Devbox](https://www.jetify.com/docs/devbox/installing-devbox).
Devbox supplies Make, Bash, and the linters.
CI uses Devbox 0.13.7 and the same Makefile targets as local development.

Start a Docker-compatible container runtime, then run the linters and build the action and test images:

```sh
devbox run -- make check
```

Individual targets include `lint-actions`, `lint-shell`, `lint-docker`, `test`, `test-release-docker`, `build`, `build-test`, and `format`.
For example, run `devbox run -- make lint-docker` to check the Dockerfiles.
You can also enter `devbox shell` and run these Make targets directly.

The test image uses `bats/bats`, which includes `bats-support` and `bats-assert`.
It copies the entrypoint and `sloctl` binary from the built action image.
Keep `devbox.lock` in version control so local development and CI use the same lint tools.

Hadolint skips package version pins because Alpine supplies package updates within the pinned base image release.
CI runs `make check` on Linux AMD64 and ARM64 runners without Nobl9 credentials.
This includes offline release tests with local Git repositories and simulated GitHub responses.
With Bats, bats-support, bats-assert, Git, jq, and GNU coreutils installed,
run the same tests without containers through `make test-release`.
Set `BATS_LIB_PATH` if the assertion libraries are outside the Bats search path.

## Live end-to-end test

The live test creates a uniquely named project in a test organization.
It runs the action entrypoint to apply the project, confirms that it exists,
runs the entrypoint to delete it, and confirms its removal.
Teardown attempts cleanup if an assertion fails and reports cleanup errors.

Export `SLOCTL_CLIENT_ID` and `SLOCTL_CLIENT_SECRET` for a test organization with permission to create and delete projects.
For a custom authentication server, also export `SLOCTL_OKTA_ORG_URL` and `SLOCTL_OKTA_AUTH_SERVER`.
Then run:

```sh
devbox run -- make test
```

The test passes credentials from the environment to the container. Missing or invalid credentials cause `sloctl` to fail the test.

## CI end-to-end check

The `End-to-end test` job runs the same `devbox run -- make test` command
on Linux AMD64.
It runs for pull requests from this repository, pushes to `main`,
merge groups, and manual workflow runs.
Fork pull requests and Dependabot runs skip this job because GitHub
does not provide Actions secrets to them.

Configure repository variables and secrets under
**Settings → Secrets and variables → Actions**.
Use credentials for a test organization with permission and quota
to create and delete projects:

| Name | Type | Required |
| --- | --- | --- |
| `SLOCTL_CLIENT_ID` | Variable | Yes |
| `SLOCTL_CLIENT_SECRET` | Secret | Yes |
| `SLOCTL_OKTA_ORG_URL` | Variable | Only for custom authentication |
| `SLOCTL_OKTA_AUTH_SERVER` | Variable | Only for custom authentication |

Missing credentials fail the check through `sloctl`.
Newer pushes do not cancel running checks, so the live test can finish cleanup.

## Releases

Each successful official sloctl release dispatches
[Update sloctl and publish action](../.github/workflows/update-sloctl.yml) on `main`.
Release candidates do not trigger this workflow.
The receiver verifies the source release run, published release, and tag commit.
It then opens a PR that updates the image pin and all action references in [README.md](../README.md).
The action keeps its own version series and increments the latest release's patch version.
For example, the first update after `v0.3.0` publishes `v0.3.1`.

The workflow waits for both architecture builds and the live end-to-end test.
It squash-merges the checked PR, waits for those checks on the merge commit,
and publishes a GitHub release with a tag at that commit.
It does not move existing tags.
Users who pin an action version must update their workflow to the new tag.

The generated `.github/sloctl-release.json` records the source release and planned action version.
Reruns resume an unfinished update or publication.
Newer updates wait in the workflow concurrency queue.
If a prior update merged but failed publication, rerun that update before the newer one.
An already published sloctl version and an older version are skipped.
Unexpected changes on the automation branch or conflicting tags fail the workflow.
If another action release takes the planned version, reconcile the pending PR or release record before retrying.

### Automation setup

Install the release automation GitHub App on this repository.
The documentation synchronization App can also serve this workflow.
It needs Actions write, Checks read, Contents write, and Pull requests write permissions.
Actions write permission allows the receiver to retry failed checks after a merge.

Create the `sloctl-release-automation` environment with:

| Name | Type | Value |
| --- | --- | --- |
| `SLOCTL_AUTOMATION_CLIENT_ID` | Variable | GitHub App client ID |
| `SLOCTL_AUTOMATION_APP_PRIVATE_KEY` | Secret | GitHub App private key |

Restrict this environment to `main`.
Allow the App to bypass required PR reviews on `main` while retaining the PR requirement.
Configure these required status checks:

- `Lint and build (ubuntu-24.04)`
- `Lint and build (ubuntu-24.04-arm)`
- `End-to-end test`

The receiver also verifies all three checks itself and submits a merge pinned to the checked commit.
It uses a direct merge request, so GitHub's native auto-merge setting is not required.
Configure the sender in the sloctl repository as described in its release documentation.
Deploy this receiver to `main` before enabling the sender.

For manual action releases, update all README references to the new explicit tag.
