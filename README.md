# Boston Digital Composer repository

To use this repository, add the following to your `~/.composer/config.json`:

```json
{
  "repositories": [
    {
      "type": "composer",
      "url": "https://boston-digital.github.io/composer/"
    }
  ]
}
```

Head over to [https://boston-digital.github.io/composer/]() to browse available packages.

### Notes
* actual composer repository is on [gh-pages](https://www.github.com/boston-digital/composer/tree/gh-pages) branch.
* if Composer complains that private packages can't be found, run `composer clearcaches`

## Updating repo

1. Change into the root directory of this repo
2. Run `make` - this will build the necessary files in the `dist` directory
3. Change into `dist` directory and push all changed files to origin