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
printf '%s\0' tests/*.harn \
  | xargs -0 -n1 -P 4 env HARN_EGRESS_BLOCK_PRIVATE=off harn run
harn test tests --parallel
```

`harn package verify . --provider github` runs the package, import, docs, and
deterministic connector-contract gates, including supported event variants and
a signature rejection case.
The `tests/fixtures/webhooks/` payloads are synthetic compatibility fixtures;
keep them free of live GitHub secrets and private repository data.

## Find the owning module

- [`src/lib.harn`](../src/lib.harn) owns the public API and its executable
  method registry.
- [`src/client.harn`](../src/client.harn) owns authentication, HTTP requests,
  pagination, and rate-limit handling.
- [`src/authoring.harn`](../src/authoring.harn) applies the selected human or
  bot identity to GitHub write bodies.
- [`src/actions.harn`](../src/actions.harn) and
  [`src/rest_methods.harn`](../src/rest_methods.harn) own direct GitHub API
  operations.
- [`src/contracts.harn`](../src/contracts.harn) owns the closed records returned
  by the public API.
- [`src/webhooks.harn`](../src/webhooks.harn) owns inbound webhook validation
  and normalization.
- [`src/worktree_commit.harn`](../src/worktree_commit.harn) owns atomic commits
  built from a local worktree.

Keep new behavior in its owning module. Add a route in `src/lib.harn` only when
the generic `call` entry point must expose it.

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
