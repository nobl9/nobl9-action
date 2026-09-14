# Development

Run the commands below from the repository root.

The Dockerfile copies `sloctl` from the official [`nobl9/sloctl` image](https://hub.docker.com/r/nobl9/sloctl).
The Alpine runtime supplies Bash and CA certificates.
Docker images and GitHub Actions use version tags. Renovate checks these dependencies for version updates.

Install [Devbox](https://www.jetify.com/docs/devbox/installing-devbox).
Devbox supplies Make, Bash, and the linters.
CI uses Devbox 0.13.7 and the same Makefile targets as local development.

Start a Docker-compatible container runtime, then run the linters and build the action and test images:

```sh
devbox run -- make check
```

Individual targets include `lint-actions`, `lint-shell`, `lint-docker`, `test`, `build`, `build-test`, and `format`.
For example, run `devbox run -- make lint-docker` to check the Dockerfiles.
You can also enter `devbox shell` and run these Make targets directly.

The test image uses `bats/bats`, which includes `bats-support` and `bats-assert`.
It copies the entrypoint and `sloctl` binary from the built action image.
Keep `devbox.lock` in version control so local development and CI use the same lint tools.

Hadolint skips package version pins because Alpine supplies package updates within the pinned base image release.
CI runs `make check` on Linux AMD64 and ARM64 runners without Nobl9 credentials.

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

Configure these GitHub Actions secrets for a test organization
with permission and quota to create and delete projects:

| Secret | Required |
| --- | --- |
| `SLOCTL_CLIENT_ID` | Yes |
| `SLOCTL_CLIENT_SECRET` | Yes |
| `SLOCTL_OKTA_ORG_URL` | Only for custom authentication |
| `SLOCTL_OKTA_AUTH_SERVER` | Only for custom authentication |

Missing credentials fail the check through `sloctl`.
Newer pushes do not cancel running checks, so the live test can finish cleanup.
