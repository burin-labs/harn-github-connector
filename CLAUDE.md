# CLAUDE.md — harn-github-connector

**Read [SESSION_PROMPT.md](./SESSION_PROMPT.md) first.** It contains the
pivot context, the connector interface contract, what's blocked on
upstream tickets (especially the JWT signing question), and the v0
milestones.

## Quick repo conventions

- File extension: `.harn`. Use `snake_case` for filenames.
- Repo directories use `kebab-case`.
- Entry point: `src/lib.harn`.
- Tests live under `tests/`. Recorded webhook fixtures live under
  `tests/fixtures/webhooks/`.

## How to test

Until `harn add` ships
([harn#345](https://github.com/burin-labs/harn/issues/345)):

```sh
cd /Users/ksinder/projects/harn
cargo run --quiet --bin harn -- run /Users/ksinder/projects/harn-github-connector/tests/normalize_smoke.harn
cargo run --quiet --bin harn -- check /Users/ksinder/projects/harn-github-connector/src/lib.harn
cargo run --quiet --bin harn -- lint  /Users/ksinder/projects/harn-github-connector/src/lib.harn
cargo run --quiet --bin harn -- fmt --check /Users/ksinder/projects/harn-github-connector/src/lib.harn
```

## Reference Rust impl

The existing 1243-LOC Rust connector at
`/Users/ksinder/projects/harn/crates/harn-vm/src/connectors/github/mod.rs`
is the **behavior spec**. Port semantics from there.

## Sibling future repo

A typed `github-sdk-harn` (REST + GraphQL) is plausible future work,
modeled after `notion-sdk-harn`. Out of scope for this repo's v0; flagged
in `SESSION_PROMPT.md`.

## Upstream conventions

For general Harn coding conventions and project layout, defer to
[`/Users/ksinder/projects/harn/CLAUDE.md`](/Users/ksinder/projects/harn/CLAUDE.md).

## Don't

- Don't bake an OpenAPI-codegen GitHub SDK into this repo. If you need a
  typed surface, propose `github-sdk-harn` as a separate repo first.
- Don't hand-edit `LICENSE-*` or `.gitignore`.
