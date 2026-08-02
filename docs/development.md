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
- [`src/actions.harn`](../src/actions.harn) owns workflow-run and self-hosted
  runner operations; [`src/rest_methods.harn`](../src/rest_methods.harn) owns
  small direct GitHub API operations.
- [`src/pull_requests.harn`](../src/pull_requests.harn) owns pull-request reads,
  edits, checks, merges, and branch-protection evidence. Match its requests to
  GitHub's [pull-request REST contract](https://docs.github.com/en/rest/pulls/pulls).
- [`src/pull_request_models.harn`](../src/pull_request_models.harn) turns raw
  GitHub responses into the connector's closed pull-request and check records.
- [`src/merge_queue.harn`](../src/merge_queue.harn) owns queue membership and
  enqueue leases; [`src/mergeability.harn`](../src/mergeability.harn) owns the
  bounded mergeability probe. GitHub's
  [GraphQL pull-request reference](https://docs.github.com/en/graphql/reference/pulls)
  defines the provider fields these modules validate.
- [`src/commits.harn`](../src/commits.harn) owns paginated pull-request commit
  evidence, signature validation, and atomic signed commits. Keep signature
  handling aligned with GitHub's
  [Git commit REST contract](https://docs.github.com/en/rest/git/commits).
- [`src/writes.harn`](../src/writes.harn) owns small write transports after
  author identity has been resolved; [`src/issues.harn`](../src/issues.harn)
  owns issue creation, comments, and template rendering.
- [`src/contracts.harn`](../src/contracts.harn) owns the closed records returned
  by the public API.
- [`src/repository.harn`](../src/repository.harn) owns repository identity,
  access checks, and exact file reads; [`src/releases.harn`](../src/releases.harn)
  owns release lookup, leased metadata edits, and asset listing.
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
