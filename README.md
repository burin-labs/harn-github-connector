# harn-github-connector

Pure-Harn GitHub App connector for the Harn orchestrator. Verifies inbound
webhook signatures, normalizes GitHub event payloads to the canonical
`TriggerEvent` shape, and dispatches outbound REST/GraphQL calls.

> **Status: v0.1.0** — production-ready first-party connector package,
> verified with the published `harn-cli` 0.7.48 release.

This is an **inbound + outbound** connector implementing the Harn Connector
Contract v1 documented in the
[Harn connector authoring guide](https://github.com/burin-labs/harn/blob/main/docs/src/connectors/authoring.md).

## Install

Install the pinned Harn CLI used by this package:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

Add the released connector package:

```sh
harn add github.com/burin-labs/harn-github-connector@v0.1.0
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

## Supported surface

Inbound webhooks:

- `issues`
- `pull_request`
- `issue_comment`
- `pull_request_review`
- `push`
- `workflow_run`
- `deployment_status`
- `check_run`

Outbound methods:

| Method | GitHub API |
|---|---|
| `github.pr.list` | Typed PR list over `GET /repos/{owner}/{repo}/pulls` |
| `github.pr.view` | Typed PR details plus branch protection summary |
| `github.pr.checks` | Typed check-run rollup over `GET /repos/{owner}/{repo}/commits/{sha}/check-runs` |
| `github.pr.merge` | Branch-protection-aware typed merge helper |
| `github.pr.comment` | Typed PR comment helper over the issues comments endpoint |
| `github.actions.logs` | Fetch Actions logs by `run_id` or by `check_id` when the check links to an Actions run |
| `github.merge_queue.entries` | Typed merge queue entries for a base branch |
| `github.merge_queue.enqueue` | Enqueue a PR on the merge queue |
| `github.issue.create` | Typed issue create helper |
| `github.issue.comment` | Typed issue comment helper |
| `github.branch.protection` | Typed branch protection summary |
| `issues.create_comment` | `POST /repos/{owner}/{repo}/issues/{issue_number}/comments` |
| `issues.create` | `POST /repos/{owner}/{repo}/issues` |
| `issues.create_with_template` | Convenience helper over `issues.create` |
| `issues.update` | `PATCH /repos/{owner}/{repo}/issues/{issue_number}` |
| `issues.add_labels` | `POST /repos/{owner}/{repo}/issues/{issue_number}/labels` |
| `pulls.list` | `GET /repos/{owner}/{repo}/pulls` |
| `pulls.list_with_checks` | GraphQL `repository.pullRequests` query with `mergeStateStatus` and `statusCheckRollup` |
| `pulls.get` | `GET /repos/{owner}/{repo}/pulls/{pull_number}` |
| `pulls.merge` | `PUT /repos/{owner}/{repo}/pulls/{pull_number}/merge` |
| `pulls.merge_safe` | Convenience helper over branch protection, pull details, merge, and optional branch deletion |
| `pulls.create_review_comment` | `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` |
| `pulls.get_diff` | `GET /repos/{owner}/{repo}/pulls/{pull_number}` with a diff `Accept` header |
| `pulls.list_files` | `GET /repos/{owner}/{repo}/pulls/{pull_number}/files` |
| `pulls.list_reviews` | `GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews` |
| `repos.get_content` | `GET /repos/{owner}/{repo}/contents/{path}` |
| `repos.get_branch_protection` | `GET /repos/{owner}/{repo}/branches/{branch}/protection` |
| `git.delete_ref` | `DELETE /repos/{owner}/{repo}/git/refs/{ref}` |
| `check_runs.create` | `POST /repos/{owner}/{repo}/check-runs` |
| `check_runs.update` | `PATCH /repos/{owner}/{repo}/check-runs/{check_run_id}` |
| `graphql` | `POST /graphql` |

## Supported methods for managed personas

Managed personas should prefer the named helpers for high-level workflows and
use `call(method, args)` only for direct method dispatch.

| Persona need | Helper or method | Notes |
|---|---|---|
| List PRs as typed records | `call("github.pr.list", {repo: "owner/name", filters: {...}})` | Returns stable fields such as `number`, `state`, `base.sha`, `head.sha`, labels, and merge-queue presence. |
| Fetch PR details with branch policy | `call("github.pr.view", {repo, number})` | Includes `base`, `head`, `mergeable_state`, `branch_protection`, and the raw payload for uncommon GitHub fields. |
| Classify checks | `call("github.pr.checks", {repo, number})` or `{repo, head_sha}` | Returns `state` as `green`, `pending`, `failing`, `dirty`, `queued`, or `merged` where enough PR context is available, plus per-check timings. |
| Fetch Actions logs | `call("github.actions.logs", {repo, run_id})` | `check_id` is also accepted when GitHub exposes an Actions run URL on the check run. |
| Use merge queue | `call("github.merge_queue.entries", {repo, branch})` and `call("github.merge_queue.enqueue", {repo, branch, pr_number, method})` | Matches the mock playground merge queue surface used by managed captain workflows. |
| List open PRs with merge state and CI rollup | `pulls_list_with_checks(owner, repo, state, limit, options)` or `call("pulls.list_with_checks", args)` | Uses GraphQL because `mergeStateStatus` and `statusCheckRollup` are GraphQL PR fields surfaced by `gh pr --json`; the REST list endpoint does not return the same check rollup shape. Returns `number`, `title`, `headRefName`, `baseRefName`, `isDraft`, `mergeStateStatus`, `statusCheckRollup`, and `url`. |
| Fetch PR details | `call("pulls.get", args)` | REST PR details for a specific PR number. |
| Merge a PR directly | `call("pulls.merge", args)` | Sends `merge_method`, `sha`, `commit_title`, and `commit_message` through to GitHub's merge endpoint. If `admin_override` is present, the response is annotated with `admin_override_requested`; GitHub still enforces the installation token's permissions. |
| Merge with branch-protection awareness | `pulls_merge_safe(owner, repo, number, options)` or `call("pulls.merge_safe", args)` | Fetches PR details, checks base branch protection, requires `admin_override` when the branch is protected, merges with the PR head SHA, and optionally deletes the head branch when `delete_branch` is true. |
| Create conflict/follow-up issues | `issues_create_with_template(owner, repo, template, vars, options)` or `call("issues.create_with_template", args)` | Renders `{{name}}` placeholders in `title` and `body`, then calls `issues.create`. |
| Update issues | `call("issues.update", args)` | Supports fields accepted by GitHub's issue update endpoint, such as `state`, `title`, `body`, `labels`, `assignees`, and `milestone`. |
| Add issue or PR labels | `call("issues.add_labels", args)` | Uses the issue-labels endpoint; GitHub models PRs as issues for labels. |
| Inspect branch protection | `call("repos.get_branch_protection", args)` | Used by `pulls.merge_safe` before admin merges. |
| List changed files | `call("pulls.list_files", args)` | Used by review/conflict workflows. |
| List reviews | `call("pulls.list_reviews", args)` | Used by review workflows. |

## GitHub App setup

Create a GitHub App and install it into the target account or repository set.
Record the App ID and Installation ID, configure a webhook secret, then store
the private key PEM in a Harn SecretProvider. Do not commit real GitHub App
private keys or webhook secrets to this repository or to consumer repos.

Inbound webhooks must include GitHub's `X-GitHub-Event`,
`X-GitHub-Delivery`, and `X-Hub-Signature-256` headers. The connector verifies
the signature against the exact raw request body using the configured
`signing_secret`.

Managed ingress hosts can pass the webhook secret by value as `signing_secret`
or by secret-provider alias through `signing_secret_id`,
`secret_ids.signing_secret`, or a binding `config.secrets.signing_secret`
mapping. In the secret-provider path, the connector reads the secret with
Harn `secret_get` during normalization.

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

- `issues.create_comment`, `issues.create`, `issues.create_with_template`,
  `issues.update`, `issues.add_labels`: Issues read/write, or Pull requests
  read/write when acting on pull requests.
- `pulls.list`, `pulls.list_with_checks`, `pulls.get`, `pulls.get_diff`,
  `pulls.list_files`, `pulls.list_reviews`: Pull requests read.
- `pulls.merge`, `pulls.merge_safe`: Pull requests write, and administrator or
  bypass permissions when merging protected branches.
- `pulls.create_review_comment`: Pull requests write.
- `repos.get_content`: Contents read.
- `repos.get_branch_protection`: Administration read.
- `git.delete_ref`: Contents write.
- `check_runs.create`, `check_runs.update`: Checks read/write.
- `graphql`: the installed app must have the permissions required by the query
  or mutation.

The connector signs a GitHub App JWT with Harn `jwt_sign`, exchanges it for an
installation access token, caches that token until its refresh window, and
invalidates the cache after a `401` response before retrying once.

If a caller already has an installation token, it can pass
`installation_token` directly. The JWT path is preferred for production because
the connector can refresh stale tokens itself.

For local development only, callers may pass `allow_gh_auth_fallback: true`.
When enabled and no installation credentials are present, the connector uses an
explicit `gh_token`, `GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth token` as the bearer
token. This fallback is intentionally gated so production workflows do not
silently depend on a user-scoped local CLI session.

## Operational limits

- Webhook normalization verifies `X-Hub-Signature-256` against the exact raw
  request body and rejects missing, unsupported, or invalid signatures.
- Webhook signing secrets may be supplied directly for local tests or resolved
  from the active Harn SecretProvider for managed ingress.
- Outbound calls use GitHub App installation tokens or a caller-provided
  installation token. OAuth user-token setup is not part of this package.
- Installation tokens are cached until the configured refresh window, refreshed
  under a mutex, invalidated after a `401`, and retried once.
- GitHub primary rate-limit responses with short reset windows are retried once;
  long reset windows return a `rate_limited` error instead of sleeping in CI or
  webhook paths.
- Outbound errors carry deterministic `category` values for typed callers:
  `auth`, `permission`, `rate_limit`, `branch_protection`, `merge_queue`,
  `checks_pending`, `checks_failed`, `network`, and `schema_drift`.
- The connector intentionally exposes a focused REST/GraphQL surface rather than
  vendoring a generated GitHub SDK.

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
harn connector check . --provider github
for test in tests/*.harn; do
  harn run "$test" || exit 1
done
```

`harn connector check . --provider github` runs the deterministic webhook
fixtures declared in `harn.toml`, including the supported webhook event variants
and a signature rejection case. The `tests/fixtures/webhooks/` payloads are
synthetic compatibility fixtures; they should stay free of live GitHub secrets
or private repository data.

For the package install/import smoke used by CI:

```sh
smoke_root="$(mktemp -d)"
cat > "$smoke_root/harn.toml" <<'EOF'
[package]
name = "harn-github-connector-consumer-smoke"
version = "0.0.0"
EOF
cd "$smoke_root"
harn add /path/to/harn-github-connector@HEAD
printf 'import "harn-github-connector/default"\n' > smoke.harn
harn check smoke.harn
```

## Release process

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
heading match, reruns the Harn connector gate, performs a clean consumer
install/import smoke, and creates or updates the GitHub Release from the
matching changelog section.

## License

Dual-licensed under MIT and Apache-2.0.

- [LICENSE-MIT](./LICENSE-MIT)
- [LICENSE-APACHE](./LICENSE-APACHE)
