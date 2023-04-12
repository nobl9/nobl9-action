# nobl9-action

This action applies a Nobl9 configuration file (specified via the sloctl_yml input parameter) to a project using the `sloctl` (https://docs.nobl9.com/sloctl-user-guide/) tool.

## Requirements

- A valid Nobl9 account (see https://nobl9.com for more information)

## Inputs

| Parameter | Description | Required | Default |
| --- | --- | --- | --- |
| `client_id` | The Client ID of your Nobl9 account | **Yes** | N/A |
| `client_secret` | The Client Secret of your Nobl9 account | **Yes** | N/A |
| `sloctl_yml` | The path or [glob pattern](https://pkg.go.dev/path/filepath#Match) to the configuration in YAML format, relative to the root directory of the repository. In order to supply multiple sources, separate them with comma (example below) | **Yes** | N/A |
| `dry_run` | Submits server-side request without persisting the configured resources | No | `false` |

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
        uses: actions/checkout@v2
      - uses: nobl9/nobl9-action@v0.2.2
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
        uses: actions/checkout@v2
      - uses: nobl9/nobl9-action@v0.2.2
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
        uses: actions/checkout@v2
      - uses: nobl9/nobl9-action@v0.2.2
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
        uses: actions/checkout@v2
      - uses: nobl9/nobl9-action@v0.2.2
        with:
          client_id: ${{ secrets.CLIENT_ID }}
          client_secret: ${{ secrets.CLIENT_SECRET }}
          sloctl_yml: "validate-slos.yaml"
          dry_run: "true"
```
