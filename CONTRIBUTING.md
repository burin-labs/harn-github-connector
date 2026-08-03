# Develop the GitHub connector

This guide runs the same deterministic package checks used in CI.

## Install the pinned Harn CLI

The `.harn-version` file records the development version for this checkout:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

## Run focused checks

Format and check changed Harn files first:

```sh
harn fmt --check src tests
harn check .
harn lint src
```

Run one test file while iterating:

```sh
harn test tests/release_view.harn
```

## Run the package gate

Before opening a pull request, run:

```sh
harn install
harn run scripts/check-source-layout.harn
harn test tests --parallel
harn package verify . --provider github
```

`harn package verify` checks the manifest, imports, generated API docs, and
Connector Contract fixtures. Fixtures under `tests/fixtures/webhooks/` are
synthetic and must not contain credentials or private repository data.

`scripts/source-layout.toml` owns source-size limits. Keep policy data there;
the Harn checker contains no filename or extension catalog.

## Update API docs

Public symbols and their documentation comments own the API reference. After
changing an export, regenerate [docs/api.md](docs/api.md):

```sh
harn package docs .
```

Do not hand-edit generated API entries.

## Prepare a release

Update `[package].version` in `harn.toml` and add the same version to
`CHANGELOG.md`. Then run:

```sh
scripts/check-release.sh vX.Y.Z
```

After the release change lands on `main`, create and push the matching tag. The
release workflow repeats the package gate, installs the package into a clean
consumer, and publishes the GitHub Release.
