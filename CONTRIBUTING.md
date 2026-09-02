# Develop the GitHub connector

This guide runs the same deterministic package checks used in CI.

## Before you start

This connector is released to the Harn package index as
`@burin/github-connector` and has live consumers, so its exported contracts are
load-bearing. Two things follow from that.

First, a change to an exported record, a method name, or an error variant is a
breaking change for someone, even when nothing in this repository fails. Say so
in the pull request and in `CHANGELOG.md`.

Second, `.github/workflows/ci.yml`, `.github/dependabot.yml`, and anything
between the `<!-- BEGIN HARN SHARED AGENT CONTRACT -->` markers in `AGENTS.md`
are projections owned by `harn-bump-fleet`. A local edit to them is overwritten
at the next fleet sync, so change them upstream instead.

Pull requests from outside Burin Labs are not accepted. If you want an
operation this connector does not have, open an issue here describing the
workflow you are trying to build, or file against
<https://github.com/burin-labs/harn/issues/new> with the label
`area/connectors` if the gap is in the connector contract rather than in this
provider.

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

Publishing the release is not the last step. `harn add @burin/github-connector`
resolves through the index at `packages.harnlang.com`, which is a separate
repository, and for three months it served 0.3.0 while this repository had
shipped through v0.8.3 (#289). The `Register in the package index` job now runs
after publishing: it asks the reconciler in `burin-labs/harn-packages` to
compare every indexed package against its upstream tags and open a pull request
recording what is missing. A release whose registration fails is a failed
release run, not a quiet success. Watch for that index pull request and merge
it; the release is not resolvable until it lands.

## Pull request titles and descriptions

Title every pull request `[Area] Sentence case description`, for example
`[Connector] Read private pull-request checks without widening App authority`.
Use one of `Connector`, `Worktree`, `Release`, `Docs`, `CI`, or `Tests`.

Keep the description to three to five sentences: what changed, why, the one
risk, and how you verified it. Name the exported contract you changed, if any,
because that is what a consumer feels.
`.github/pull_request_template.md` carries a worked example.

A pull request that resolves an issue names which of the issue's sub-asks it
closes: `Closes #N items: 1, 3`, or `Single-ask: #N` when the issue is not
enumerated.

## Labels

`.github/labels.yml` records the label vocabulary. Priority, status, and effort
come from the org taxonomy in
[burin-labs/.github](https://github.com/burin-labs/.github); `area/*` is local
to this repository. Reuse `bug`, `enhancement`, and `documentation` for type
rather than adding a `type/*` prefix.

## Reporting a bug

Open an issue at
<https://github.com/burin-labs/harn-github-connector/issues/new> with the
connector version, the operation you called, and the typed error you got back.
Webhook fixtures in an issue must be synthetic. Never paste an installation
token, an App private key, or a webhook signing secret.
