# Contributing

Fork the repository and create a branch for your change. Open a pull request
with the problem, resulting behavior and checks you ran. Use issues for bug
reports, feature requests and data corrections.

## Run the checks

Install Node.js 24 and Python 3.10 or newer. From the repository root, run:

```sh
npm ci --ignore-scripts
npm test
python tools/package.py
```

Tests use mocked WoW APIs. Record in-game checks separately, including the
client build, add-on version and other add-ons involved. Never call a mocked
test an in-game test. Add regression coverage when changing runtime behavior.

The package builder uses release-manifest.json. Update that manifest when
adding installable files. The ZIP and SHA256SUMS.txt go into dist/. They do
not include this repository's tests, dependencies or development settings.

Do not commit account files, WTF directories, saved variables, credentials
or downloaded caches. Keep third-party notices with their source data.
Contributions use the applicable license in this repository. Describe any
third-party material and its source in your pull request.

## Test dependency advisory

The development-only Fengari dependency currently pulls in sprintf-js with
a moderate unbounded-precision denial-of-service advisory, GHSA-hp3w-g68c-fv3c.
No fixed version is available in the current dependency chain. Run the tests
only on trusted local test inputs. These Node packages are absent from the
installable add-on ZIP.
