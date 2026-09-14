# nobl9-action

This action applies or deletes Nobl9 resources defined in files supplied through `sloctl_yml`, using [`sloctl`](https://docs.nobl9.com/sloctl-user-guide/).
The default operation is `apply`.

## Requirements

- A valid Nobl9 account (see https://nobl9.com for more information)

## Inputs

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `client_id` | The Client ID of your Nobl9 account | **Yes** | N/A |
| `client_secret` | The Client Secret of your Nobl9 account | **Yes** | N/A |
| `oktaOrgURL` | Okta organization URL for your Nobl9 account | No | sloctl default |
| `oktaAuthServer` | Okta authorization server ID for your Nobl9 account | No | sloctl default |
| `sloctl_yml` | The path or [glob pattern](https://pkg.go.dev/path/filepath#Match) to the configuration in YAML format, relative to the root directory of the repository. In order to supply multiple sources, separate them with comma (example below) | **Yes** | N/A |
| `operation` | The operation to run: `apply` or `delete`. Other values are rejected. | No | `apply` |
| `dry_run` | Submits the selected operation to the server without changing resources | No | `false` |

## Example Usage

### Apply single file
```yaml
name: Nobl9 GitHub Actions Demo
on: [push]
jobs:
  nobl9:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository code
        uses: actions/checkout@v7
      - uses: nobl9/nobl9-action@latest
        with:
          client_id: ${{ secrets.CLIENT_ID }}
          client_secret: ${{ secrets.CLIENT_SECRET }}
          sloctl_yml: "slos.yaml"
```

### Recursively apply multiple files using glob pattern
```yaml
name: Nobl9 GitHub Actions Demo
on: [push]
jobs:
  nobl9:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository code
        uses: actions/checkout@v7
      - uses: nobl9/nobl9-action@latest
        with:
          client_id: ${{ secrets.CLIENT_ID }}
          client_secret: ${{ secrets.CLIENT_SECRET }}
          sloctl_yml: "**"
```

### Apply from multiple sources
```yaml
name: Nobl9 GitHub Actions Demo
on: [push]
jobs:
  nobl9:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository code
        uses: actions/checkout@v7
      - uses: nobl9/nobl9-action@latest
        with:
          client_id: ${{ secrets.CLIENT_ID }}
          client_secret: ${{ secrets.CLIENT_SECRET }}
          sloctl_yml: "my slo1.yaml,my-slo2.yml,dir/my-slo3.json"
```

### Dry run
```yaml
name: Nobl9 GitHub Actions Demo
on: [push]
jobs:
  nobl9:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository code
        uses: actions/checkout@v7
      - uses: nobl9/nobl9-action@latest
        with:
          client_id: ${{ secrets.CLIENT_ID }}
          client_secret: ${{ secrets.CLIENT_SECRET }}
          sloctl_yml: "validate-slos.yaml"
          dry_run: "true"
```

### Delete resources

Set `operation: delete` in the action step to delete resources defined in the supplied files:

```yaml
with:
  client_id: ${{ secrets.CLIENT_ID }}
  client_secret: ${{ secrets.CLIENT_SECRET }}
  sloctl_yml: "slos.yaml"
  operation: "delete"
```

Delete also supports comma-separated paths, glob patterns, and `dry_run: "true"`.

### Custom authentication

For accounts that use a custom Okta organization or authorization server, set these inputs to match your `sloctl` configuration:

```yaml
with:
  client_id: ${{ secrets.CLIENT_ID }}
  client_secret: ${{ secrets.CLIENT_SECRET }}
  sloctl_yml: "slos.yaml"
  oktaOrgURL: ${{ vars.OKTA_ORG_URL }}
  oktaAuthServer: ${{ vars.OKTA_AUTH_SERVER }}
```

Omit either input or leave it empty to use the corresponding sloctl default.

## Development

See the [development guide](docs/DEVELOPMENT.md) for setup, checks, and live tests.
