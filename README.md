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
    if event.action == "opened" {
      github_connector.call("issues.create_comment", {
        owner: event.repo.owner,
        repo: event.repo.name,
        issue_number: event.pull_request.number,
        body: "Thanks for the PR!",
      })
    }
  }
}
```

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
harn fmt --check src/lib.harn
for test in tests/*.harn; do
  harn run "$test" || exit 1
done
```

## JWT signing gap

GitHub App installation token rotation requires a signed app JWT. Harn v0.7.30
does not expose a JWT signing builtin
([harn#453](https://github.com/burin-labs/harn/issues/453)), so v0 requires
`installation_token`/`GITHUB_INSTALLATION_TOKEN` for outbound calls. Token
minting and refresh are intentionally deferred until the upstream JWT builtin
lands.


## License

Dual-licensed under MIT and Apache-2.0.

- [LICENSE-MIT](./LICENSE-MIT)
- [LICENSE-APACHE](./LICENSE-APACHE)
