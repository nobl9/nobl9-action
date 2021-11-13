# nobl9-action

This action is applying a nobl9 configuration file (specified at `sloctl_yml` input parameter) to a project using `sloctl` (https://nobl9.github.io/techdocs_Sloctl_User_Guide) tool.

# Requirements

- Before running this action, the code must be checked out already (see https://github.com/actions/checkout).
- A valid nobl9 account must be activated (check https://nobl9.com for more information)


# Usage

This action supports GitHub actions secrets in all the input parameters. More details: https://docs.github.com/en/actions/reference/encrypted-secrets.

Example:
```yaml
- uses: catacraciun/nobl9-action@v0.2.0
  with:
    # This references to a custom `NOBL9_CLIENT_ID` secret defined in GitHub project settings 
    client_id: ${{ secrets.NOBL9_CLIENT_ID }}
```

Input parameters:

<!-- start usage -->
```yaml
- uses: catacraciun/nobl9-action@v0.2.0
  with:
    # The Client ID of your nobl9 account
    client_id: ''

    # The Client Secret of your nobl9 account
    client_secret: ''

    # Access token used to authenticate the sloctl tool
    access_token: ''

    # The project name on which the sloctl configuration will be applied to
    project: ''

    # The path to the sloctl yaml configuration file, relative to the root directory of the repository
    sloctl_yml: ''
```
<!-- end usage -->
