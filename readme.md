# WordPress Plugin Repository Readme/Assets Updater

> Deploys updates to readme file and assets to the WordPress Plugin Repository.

This Action is a derivative of [10up/action-wordpress-plugin-asset-update](https://github.com/10up/action-wordpress-plugin-asset-update).

The main differences are that this version:

* Only looks at the readme file and assets. Other changes to the specified branch are ignored.
* Does not require executing any build steps inside the action if your plugin uses those (Example: `composer install`, `npm install`, etc.)
* Will generate an error and not deploy the changes if the tag specified by the `Stable tag` header is not found in the WordPress plugin repository. (Technically this is something that is permitted by the plugin repository system, as it will fall back to using `trunk`, but best practice is to also push a tag if one is specified in the `Stable tag` plugin header. If you don't want to use tags in SVN, you can omit that header or use `trunk`.)

## Details
This Action pushes any changes to the readme and/or assets used by the WordPress.org plugin repository in the branch specified by the workflow file to the SVN repo on WordPress.org. This is useful for updating things like screenshots or `Tested up to` separately from functional changes.

Because the WordPress.org plugin repository shows information from the readme in the specified `Stable tag`, this Action also attempts to parse out the stable tag from your readme and deploy to there as well as `trunk`. If the `Stable tag` header is missing or set to `trunk`, it will skip that part of the update and only update `trunk` and/or `assets`. If the specified tag is missing from the SVN repository, it will exit with an error and not deploy any changes.

**Important note:** If your development process leads to a situation where the branch specified in the workflow configuration contains changes to the readme or assets directory and those changes are in preparation for the next release, those changes will go live and potentially be misleading to users.

## Configuration

### Required secrets

* `SVN_USERNAME`
* `SVN_PASSWORD`

[Secrets are set in your repository settings](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets). They cannot be viewed once stored.

### Optional environment variables

* `SLUG` - Defaults to the respository name. Customizable in case your WordPress repository has a different slug or is capitalized differently.
* `ASSETS_DIR` - Defaults to `.wporg`. Customizable for other locations of WordPress.org plugin repository-specific assets that belong in the top-level `assets` directory (the one on the same level as `trunk`).
* `README_NAME` - Defaults to `readme.txt`. Customizable in case you use `README.md` instead, which is now quietly supported in the WordPress.org plugin repository.

## Example Workflow File

```yml
name: Plugin asset/readme update
on:
  push:
    branches:
	  - master
	paths:
	  - .wporg/*
	  - readme.txt
jobs:
  master:
    name: Push to master
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: WordPress.org plugin asset/readme update
      uses: bluehost/wp-plugin-readme-assets-updater@master
      env:
        SVN_PASSWORD: ${{ secrets.SVN_PASSWORD }}
        SVN_USERNAME: ${{ secrets.SVN_USERNAME }}
```
