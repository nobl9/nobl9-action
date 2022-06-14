# nobl9-action

This action applies a Nobl9 configuration file (specified via the sloctl_yaml input parameter) to a project using the `sloctl` (https://docs.nobl9.com/sloctl-user-guide/) tool.

## Requirements

- A valid Nobl9 account (see https://nobl9.com for more information)

## Inputs

### `client_id`
The Client ID of your Nobl9 account

### `client_secret`
The Client Secret of your Nobl9 account

### `access_token`
The access token used to authenticate to the sloctl tool

### `project`
The name of the project the configuration will be applied to

### `sloctl_yaml`
The path to the sloctl YAML configuration file, relative to the root directory of the repository

## Example Usage

```yaml
name: Nobl9 GitHub Actions Demo
on: [push]
jobs:
  nobl9:
    runs-on: ubuntu-latest
    steps:
      - name: Check out repository code
        uses: actions/checkout@v2
      - uses: nobl9/nobl9-action@v0.2.0
        with:
          client_id: ${{ secrets.CLIENT_ID }}
          client_secret: ${{ secrets.CLIENT_SECRET }}
          access_token: ${{ secrets.ACCESS_TOKEN }}
          project: "myproject"
          sloctl_yml: "slos.yaml"
```
