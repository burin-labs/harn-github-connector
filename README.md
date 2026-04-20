# harn-github-connector

Pure-Harn GitHub App connector for the Harn orchestrator. Verifies inbound
webhook signatures, rotates installation tokens, normalizes GitHub event
payloads to the canonical `TriggerEvent` shape, and dispatches outbound
REST/GraphQL calls.

> **Status: pre-alpha** — actively developed in tandem with
> [burin-labs/harn](https://github.com/burin-labs/harn). See the
> [Pure-Harn Connectors Pivot epic #350](https://github.com/burin-labs/harn/issues/350).

This is an **inbound + outbound** connector implementing the Harn Connector
interface defined in
[harn#346](https://github.com/burin-labs/harn/issues/346).

## Install

Once Harn package management v0
([harn#345](https://github.com/burin-labs/harn/issues/345)) lands:

```sh
harn add github.com/burin-labs/harn-github-connector@v0.1.0
```

Until then, depend on this repo via a path import:

```toml
[dependencies]
harn-github-connector = { path = "../harn-github-connector" }
```

## Usage

```harn
import github_connector from "harn-github-connector"

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

This repo is being built out by Claude Code sessions following a structured
prompt. **Read [SESSION_PROMPT.md](./SESSION_PROMPT.md) before making changes.**

## License

Dual-licensed under MIT and Apache-2.0.

- [LICENSE-MIT](./LICENSE-MIT)
- [LICENSE-APACHE](./LICENSE-APACHE)
