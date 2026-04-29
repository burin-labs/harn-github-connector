# AGENTS.md — harn-github-connector

This repository ships the first-party pure-Harn GitHub connector package.
Treat `harn.toml`, `src/lib.harn`, and the deterministic fixtures in `tests/`
as the current source of truth for connector behavior.

## Quick repo conventions

- File extension: `.harn`. Use `snake_case` for filenames.
- Repo directories use `kebab-case`.
- Entry point: `src/lib.harn`.
- Tests live under `tests/`. Recorded webhook fixtures live under
  `tests/fixtures/webhooks/`.

## How to test

Install the pinned Harn CLI from crates.io:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

Run checks from the repo root:

```sh
harn check src/lib.harn
harn lint src/lib.harn
harn fmt --check src tests
harn connector check . --provider github
for test in tests/*.harn; do
  harn run "$test" || exit 1
done
```

## Reference Rust impl

The existing 1243-LOC Rust connector at
`/Users/ksinder/projects/harn/crates/harn-vm/src/connectors/github/mod.rs`
is the **behavior spec**. Port semantics from there.

## Sibling future repo

A typed `github-sdk-harn` (REST + GraphQL) is plausible future work,
modeled after `notion-sdk-harn`. It is out of scope for this connector package.

## Upstream conventions

For general Harn coding conventions and project layout, defer to
[`/Users/ksinder/projects/harn/AGENTS.md`](/Users/ksinder/projects/harn/AGENTS.md).

## Don't

- Don't bake an OpenAPI-codegen GitHub SDK into this repo. If you need a
  typed surface, propose `github-sdk-harn` as a separate repo first.
- Don't hand-edit `LICENSE-*` or `.gitignore`.
