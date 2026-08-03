# Harn GitHub connector

Use GitHub from Harn without rebuilding authentication, webhook verification,
retry policy, pagination, or response validation in each agent workflow.

The connector provides:

- typed request records for common GitHub operations;
- closed success and error records at orchestration boundaries;
- verified, normalized GitHub webhook events;
- GitHub App installation-token caching and refresh;
- leased mutations for pull requests, releases, branches, and commits; and
- a separate adapter for publishing a local Git state as a GitHub-signed
  commit.

Harn owns the connector runtime and capability boundary. GitHub remains the
source of truth for repository state, permissions, rulesets, and audit data.
Use `std/git` for local repository operations and `std/gh` only as an explicit
GitHub CLI escape hatch. This connector owns remote GitHub authentication,
REST and GraphQL normalization, mutation leases, and provider errors.

## Install

Install a compatible Harn CLI, then add the connector:

```sh
cargo install harn-cli --version 0.10.53 --locked
harn add github.com/burin-labs/harn-github-connector@v0.7.0
```

Add the released connector:

```sh
harn add github.com/burin-labs/harn-github-connector@v0.7.0
```

For local multi-repo development, use a path dependency:

```toml
[dependencies]
harn-github-connector = { path = "../harn-github-connector" }
```

## Make a typed call

Every high-level helper takes two arguments: the host `Harness` and one typed
request record. Named fields keep repository names, tags, pull-request numbers,
leases, and credentials distinct at the call site.

```harn
import {
  GithubConnectorResult,
  GithubReleaseLookup,
  github_release,
} from "harn-github-connector/default"

fn find_release(
  harness: Harness,
) -> GithubConnectorResult<GithubReleaseLookup> {
  return github_release(
    harness,
    {
      owner: "octo-org",
      repo: "octo-repo",
      tag: "v1.2.3",
      options: {
        installation_token: env("GITHUB_INSTALLATION_TOKEN"),
      },
    },
  )
}
```

Handle the `Result` before reading the success value:

```harn
const result = find_release(harness)
if is_err(result) {
  throw unwrap_err(result).message
}
const lookup = unwrap(result)
```

Use a named helper when one exists. Use `api_call(harness, request)` only for a
GitHub REST operation that has no typed helper. The complete generated symbol
reference is in [API reference](docs/api.md).

## Choose the next guide

- [Set up a GitHub App](docs/setup.md) — configure credentials, permissions,
  and webhook delivery.
- [Webhook event reference](docs/events.md) — find supported events, topics,
  and promoted fields.
- [Publish a GitHub-signed commit](docs/worktree-commits.md) — send one exact
  local Git state to an automation branch.
- [Safety model](docs/safety-model.md) — understand leases, absence proofs,
  retry rules, identity, and forge boundaries.
- [API reference](docs/api.md) — look up exported functions and types.
- [Development](CONTRIBUTING.md) — run checks and prepare changes.

The package implements
[Harn Connector Contract v1](https://github.com/burin-labs/harn/blob/main/docs/src/connectors/authoring.md).

## License

Dual-licensed under [MIT](LICENSE-MIT) and [Apache-2.0](LICENSE-APACHE).
