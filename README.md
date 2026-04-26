# harn-github-connector

Pure-Harn GitHub App connector for the Harn orchestrator. Verifies inbound
webhook signatures, normalizes GitHub event payloads to the canonical
`TriggerEvent` shape, and dispatches outbound REST/GraphQL calls.

> **Status: pre-alpha** — actively developed in tandem with
> [burin-labs/harn](https://github.com/burin-labs/harn). See the
> [Pure-Harn Connectors Pivot epic #350](https://github.com/burin-labs/harn/issues/350).

This is an **inbound + outbound** connector implementing the Harn Connector
interface defined in
[harn#346](https://github.com/burin-labs/harn/issues/346).

## Install

```sh
harn add github.com/burin-labs/harn-github-connector@main
```

For local multi-repo development, a path dependency is still useful:

```toml
[dependencies]
harn-github-connector = { path = "../harn-github-connector" }
```

## Usage

```harn
import github_connector from "harn-github-connector/default"

trigger pr_review on github {
  source = {
    kind: "webhook",
    app_id: env("GITHUB_APP_ID"),
    installation_id: env("GITHUB_INSTALLATION_ID"),
    events: ["pull_request"],
  }
  on event {
    if event.kind == "pull_request" && event.payload.action == "opened" {
      github_connector.call("issues.create_comment", {
        owner: event.payload.repository.owner.login,
        repo: event.payload.repository.name,
        issue_number: event.payload.pull_request.number,
        body: "Thanks for the PR!",
      })
    }
  }
}
```

## GitHub App setup

Create a GitHub App and install it into the target account or repository set.
Record the App ID and Installation ID, configure a webhook secret, then store
the private key PEM in a Harn SecretProvider. Do not commit real GitHub App
private keys or webhook secrets to this repository or to consumer repos.

Inbound webhooks must include GitHub's `X-GitHub-Event`,
`X-GitHub-Delivery`, and `X-Hub-Signature-256` headers. The connector verifies
the signature against the exact raw request body using the configured
`signing_secret`.

Example outbound call configuration:

```harn
github_connector.call("issues.create_comment", {
  app_id: env("GITHUB_APP_ID"),
  installation_id: env("GITHUB_INSTALLATION_ID"),
  private_key_secret: "github/app-private-key",
  owner: "octo-org",
  repo: "demo",
  issue_number: 123,
  body: "Thanks for the PR!",
})
```

For local fixture tests only, `private_key_pem` can be passed inline. Production
setup should use `private_key_secret` so the PEM is resolved through
`secret_get`.

Required GitHub App permissions depend on the outbound method:

- `issues.create_comment`, `issues.update`: Issues read/write, or Pull requests
  read/write when commenting on pull requests.
- `pulls.create_review_comment`, `pulls.list_files`: Pull requests read/write.
- `repos.get_content`: Contents read.
- `check_runs.create`, `check_runs.update`: Checks read/write.
- `graphql`: the installed app must have the permissions required by the query
  or mutation.

The connector signs a GitHub App JWT with Harn `jwt_sign`, exchanges it for an
installation access token, caches that token until its refresh window, and
invalidates the cache after a `401` response before retrying once.

If a caller already has an installation token, it can pass
`installation_token` directly. The JWT path is preferred for production because
the connector can refresh stale tokens itself.

## Development

Install the pinned Harn CLI from crates.io:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

Run the local CI equivalent from this repo:

```sh
harn check src/lib.harn
harn lint src/lib.harn
harn fmt --check src tests
harn connector check .
for test in tests/*.harn; do
  harn run "$test" || exit 1
done
```

`harn connector check .` runs the deterministic webhook fixtures declared in
`harn.toml`, including the webhook event variants supported by the legacy Rust
GitHub connector and a signature rejection case. The `tests/fixtures/webhooks/`
payloads are synthetic compatibility fixtures; they should stay free of live
GitHub secrets or private repository data.

## License

Dual-licensed under MIT and Apache-2.0.

- [LICENSE-MIT](./LICENSE-MIT)
- [LICENSE-APACHE](./LICENSE-APACHE)
