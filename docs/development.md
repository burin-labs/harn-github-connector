# Develop and release the connector

## Install the toolchain

Install the pinned Harn CLI from crates.io:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

## Run the full check

```sh
harn install
harn check src
harn lint src
harn fmt --check src tests
harn package verify . --provider github
harn test tests --parallel
```

`harn package verify . --provider github` runs the package, import, docs, and
deterministic connector-contract gates, including supported event variants and
a signature rejection case.
The `tests/fixtures/webhooks/` payloads are synthetic compatibility fixtures;
keep them free of live GitHub secrets and private repository data.

## Put tests in the owning lane

Use the narrowest test that can disprove the claim:

| Lane | Use it for | I/O |
| --- | --- | --- |
| `tests/unit/` | Pure parsing, validation, and normalization. | None. |
| `tests/contract/` | Public types, GitHub request/response rules, leases, receipts, and provider errors. | `Harness` HTTP mocks only. |
| `tests/integration/` | Behavior that crosses connector modules or uses a temporary local Git repository. | Local process and filesystem capabilities; no live GitHub calls. |
| Package smoke | Installing the built package and importing every export. | A temporary consumer package created by `harn package verify`. |

`harn test tests --parallel` discovers every nested test lane. Keep one test
file beside the behavior it proves and name the falsifier in the pipeline name.
Do not use live GitHub calls in the deterministic suite.

Harn language and runtime conformance belongs in Harn's
[`conformance/tests`](https://github.com/burin-labs/harn/tree/main/conformance/tests).
Connector protocol fixtures remain in `harn.toml` and run through
`harn connector check`; do not copy them into a second conformance catalog.

Use a live installation only for a release smoke that cannot be proven with
the package consumer or connector fixtures. Record the repository, exact
commit, operation, and cleanup receipt when such a smoke is required.

## Find the owning module

Open the [module ownership reference](reference/module-ownership.md), then edit
the module that owns the behavior. Add a method to `src/dispatch.harn` only when
the generic `call` API must expose it. Export public functions through
`src/lib.harn`.

## Release

Release validation is tag-driven. Before tagging, update `[package].version` in
`harn.toml` and add a matching `CHANGELOG.md` heading, then run:

```sh
scripts/check-release.sh vX.Y.Z
```

After the release PR lands on `main`, create and push the tag:

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

The Release workflow verifies that the tag, manifest version, and changelog
heading match, reruns the Harn connector gate, performs a clean consumer smoke,
and creates or updates the GitHub Release from the matching changelog section.
