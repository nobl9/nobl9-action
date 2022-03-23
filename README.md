# nobl9-action

This action applies a Nobl9 configuration file (specified at `sloctl_yml` input parameter) to a project using `sloctl` (https://docs.nobl9.com/sloctl-user-guide/) tool.

## Requirements

- A valid nobl9 account must be activated (check https://nobl9.com for more information)

## Inputs

### `client_id`
The Client ID of your nobl9 account

### `client_secret`
The Client Secret of your nobl9 account

### `access_token`
Access token used to authenticate the sloctl tool

### `project`
The project name on which the sloctl configuration will be applied to

### `sloctl_yml`
The path to the sloctl yaml configuration file, relative to the root directory of the repository

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
