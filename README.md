# harn-github-connector

Pure-Harn GitHub App connector for signed webhooks and typed REST and GraphQL
operations. It implements Harn Connector Contract v1.

The [Harn connector authoring guide](https://github.com/burin-labs/harn/blob/main/docs/src/connectors/authoring.md)
defines the shared connector contract. This repository documents GitHub-specific
setup and behavior.

## Install

Install the Harn version pinned by this repository:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

Add the released package:

```sh
harn add github.com/burin-labs/harn-github-connector@v0.5.0
```

For local development, use a path dependency:

```toml
[dependencies]
harn-github-connector = { path = "../harn-github-connector" }
```

## Make an outbound call

Every call returns `Result<value, GithubConnectorError>`. Pass `Harness` so the
connector uses the host's network, secrets, clock, process, and runtime state.

```harn
import { call } from "harn-github-connector/default"

fn main(harness: Harness) {
  const result = call(harness, "github.issue.comment", {
    owner: "octo-org",
    repo: "octo-repo",
    issue_number: 123,
    body: "Thanks for the pull request.",
  })
  if is_err(result) {
    throw unwrap_err(result).message
  }
}
```

Configure a GitHub App before making live calls. The connector can mint and
cache installation tokens or accept a caller-provided installation token.

## Documentation

- [Configure a GitHub App](docs/how-to/configure-github-app.md)
- [Publish a worktree as a GitHub-signed commit](docs/how-to/publish-a-worktree-commit.md)
- [Webhook reference](docs/reference/webhooks.md)
- [Outbound API reference](docs/reference/outbound-api.md)
- [Generated API index](docs/api.md)
- [Runtime policy reference](docs/reference/runtime-policy.md)
- [Module ownership reference](docs/reference/module-ownership.md)
- [Develop and release the connector](docs/development.md)

## License

Dual-licensed under MIT and Apache-2.0.

- [MIT license](LICENSE-MIT)
- [Apache 2.0 license](LICENSE-APACHE)
