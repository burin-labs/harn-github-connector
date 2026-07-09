# harn-github-connector

Pure-Harn GitHub App connector for the Harn orchestrator. It verifies inbound
webhook signatures, normalizes GitHub events to Harn `TriggerEvent` payloads,
and dispatches outbound REST and GraphQL calls.

The package implements the Harn Connector Contract v1. Shared connector rules
live in the
[Harn connector authoring guide](https://github.com/burin-labs/harn/blob/main/docs/src/connectors/authoring.md).

Use `.harn-version` as the source of truth for the tested `harn-cli` release.

## Install

Install the pinned Harn CLI:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

Add the released connector:

```sh
harn add github.com/burin-labs/harn-github-connector@v0.3.0
```

For local multi-repo development, use a path dependency:

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

## Inbound webhooks

Supported GitHub events:

```text
issues
pull_request
issue_comment
pull_request_review
push
workflow_run
deployment_status
check_run
check_suite
status
merge_group
installation
installation_repositories
release
```

Normalized payloads keep the raw GitHub payload under `raw` and promote stable
fields for Harn consumers:

| Field | Notes |
|---|---|
| `provider` | Always `github`. |
| `event` | GitHub event kind, such as `pull_request` or `merge_group`. |
| `topic` | `github.<event>` or `github.<event>.<action>`. |
| `reaction_topics` | Semantic `github.reaction.*` topics derived from the payload. |
| `action` | GitHub payload action when present. |
| `delivery_id` | `X-GitHub-Delivery`; also used for the dedupe key. |
| `installation_id` | GitHub App installation id when present. |
| `repository` / `repo` | Raw repository plus normalized `{owner, name, full_name}`. |
| `source` / `source_refs` | Provider-neutral source refs with repo slugs, resource ids, and links. |
| `mention` | `@handle command args...` directives parsed from issue/PR/comment bodies: `{candidates: [{handle, command, rest}], actor, command, handle, rest, issue_number?, comment_id?, html_url?}`. CPU-only; downstream filters `candidates` by bot identity. |
| `triage_event` | `harn.triage_event.v1` envelope for issues, PRs, comments, and reviews. |
| `job_event` | `harn.job_event.v1` envelope for checks, runs, releases, pushes, deployments, and merge queue events. |
| `raw` | Original GitHub payload for fields not promoted by the connector. |

Dashboard envelopes promote the fields Burin Home and Harn Cloud need to render
source-linked task and job cards: URL, timestamp, actors, summary, proposed
action, priority/status, dedupe key, privacy flags, related refs, and action
intents. Provider write intents are descriptive and carry
`requires_approval: true`; hosts decide whether to approve and execute them.

Merge Captain and release consumers should subscribe to these topics:

| Topic | Promoted fields |
|---|---|
| `github.pull_request.<action>` | `pull_request`, `pull_request_number`, `head_sha`, `head_ref`, `base_sha`, `base_ref`, `draft`, `merged`, `labels` |
| `github.check_run.<action>` | `check_run`, `check_id`, `check_run_id`, `check_suite_id`, `pull_request_number`, `head_sha`, `head_ref`, `base_ref`, `name`, `status`, `conclusion` |
| `github.check_suite.<action>` | `check_suite`, `check_suite_id`, `pull_request_number`, `head_sha`, `head_ref`, `base_ref`, `status`, `conclusion` |
| `github.workflow_run.<action>` | `workflow_run`, `run_id`, `run_number`, `workflow_id`, `check_suite_id`, `pull_request_number`, `head_sha`, `head_ref`, `base_ref`, `name`, `status`, `conclusion` |
| `github.status` | `commit_status`, `status_id`, `head_sha`, `head_ref`, `base_ref`, `state`, `context`, `target_url` |
| `github.merge_group.<action>` | `merge_group`, `merge_group_id`, `head_sha`, `head_ref`, `base_sha`, `base_ref`, `pull_requests`, `pull_request_numbers` |
| `github.push` | `ref`, `ref_name`, `before`, `after`, `head_sha`, `head_ref`, `commits`, `distinct_size`, `head_commit`, `pusher`, `created`, `deleted`, `forced` |
| `github.installation.<action>` | `installation`, `account`, `installation_state`, `suspended`, `revoked`, `repositories` |
| `github.installation_repositories.<action>` | `installation`, `account`, `installation_state`, `suspended`, `revoked`, `repository_selection`, `repositories_added`, `repositories_removed` |
| `github.release.<action>` | `release`, `release_id`, `tag_name`, `name`, `draft`, `prerelease`, `target_commitish`, `published_at`, `assets` |

Semantic reaction topics:

| Topic | Emitted when |
|---|---|
| `github.reaction.ci_failure` | A `check_run`, `check_suite`, `workflow_run`, or legacy `status` payload concludes in a failure/error state. |
| `github.reaction.merge_conflict` | A pull request payload reports `mergeable_state: "dirty"`. |

## Outbound calls

Call methods through `call(method, args)` unless a named helper fits better.

| Area | Methods |
|---|---|
| Pull requests | `github.pr.list`, `github.pr.view`, `github.pr.checks`, `github.pr.merge`, `github.pr.enable_auto_merge`, `github.pr.comment`, `pulls.list`, `pulls.list_with_checks`, `pulls.get`, `pulls.create`, `pulls.merge`, `pulls.merge_safe`, `pulls.create_review_comment`, `pulls.get_diff`, `pulls.list_files`, `pulls.list_reviews`, `pull_requests.resolve_mergeable`, `repos.commit_pulls` |
| Actions and checks | `github.actions.workflow_dispatch`, `github.actions.runs`, `github.actions.run`, `github.actions.logs`, `actions.workflow_dispatch`, `actions.workflow_runs.list`, `actions.workflow_run.get`, `check_runs.create`, `check_runs.update` |
| Self-hosted runners | `actions.runners.registration_token`, `actions.runners.remove_token`, `actions.runners.generate_jitconfig`, `actions.runners.list`, `actions.runners.get`, `actions.runners.delete`, `actions.runners.downloads`, `actions.runners.labels.list`, `actions.runners.labels.add`, `actions.runners.labels.replace`, `actions.runners.labels.remove`, `actions.runner_groups.list`, `actions.runner_groups.create`, `actions.runner_groups.get`, `actions.runner_groups.update`, `actions.runner_groups.delete` |
| User OAuth | `oauth.user.device_code`, `oauth.user.device_poll`, `oauth.user.exchange_code`, `oauth.user.refresh` |
| Issues | `github.issue.create`, `github.issue.comment`, `issues.create_comment`, `issues.create`, `issues.create_with_template`, `issues.update`, `issues.add_labels` |
| Repository and release data | `github.release.latest`, `github.release.assets`, `github.branch.protection`, `repos.get_content`, `repos.get_text`, `repos.create_or_update_file`, `repos.put_content`, `repos.delete_file`, `repos.get_latest_release`, `repos.list_release_assets`, `repos.get_branch_protection`, `git.create_commit`, `git.delete_ref` |
| Merge queue | `github.merge_queue.entries`, `github.merge_queue.enqueue` |
| Raw access | `api_call`, `graphql` |

Named helpers:

| Helper | Purpose |
|---|---|
| `pulls_list_with_checks(owner, repo, state, limit, options)` | List PRs with merge state and CI rollup. |
| `pulls_merge_safe(owner, repo, number, options)` | Merge after checking branch protection. |
| `pulls_enable_auto_merge(owner, repo, number, options)` | Enable GitHub auto-merge. |
| `actions_workflow_dispatch(owner, repo, workflow_id, ref, inputs, options)` | Dispatch a workflow. |
| `actions_workflow_runs(owner, repo, options)` | List workflow runs. |
| `api_call(path, method, body, options)` | Call one REST endpoint. Prefer typed helpers when available. |
| `repos_get_text(owner, repo, path, ref, options)` | Decode repository file content as UTF-8 text. |
| `repos_get_latest_release(owner, repo, options)` | Fetch latest release metadata. |
| `repos_list_release_assets(owner, repo, release_id, options)` | List assets for a release id. |
| `github_latest_release(owner, repo, options)` | Fetch latest release metadata in a stable envelope. |
| `github_release_assets(owner, repo, release_id, options)` | List release assets in a stable envelope; defaults to the latest release. |
| `issues_create_with_template(owner, repo, template, vars, options)` | Render a small title/body template, then create an issue. |
| `github_dispatch_workflow_and_wait(owner, repo, workflow_id, ref, inputs, options)` | Dispatch a workflow and wait for completion. |
| `github_wait_for_workflow_run(owner, repo, run_id_or_filter, options)` | Poll an existing workflow run or a filtered run lookup. |
| `github_ensure_auto_merge(owner, repo, pull_number, options)` | Enable auto-merge and normalize already-enabled responses. |
| `github_wait_for_pr_checks(owner, repo, pull_number_or_ref, options)` | Wait for visible PR or commit checks; optionally attach failing Actions log tails. |
| `github_find_open_pr(owner, repo, options)` | Find the first open PR matching `head_ref`, `base_ref`, `title`, or `labels`. |
| `github_close_pr(owner, repo, pull_number, comment, options)` | Close a PR and optionally post a final comment. |
| `github_resolve_mergeable(owner, repo, pull_number, options)` | Resolve a PR's async `mergeable`/`mergeable_state` with bounded polling; returns `{mergeable, mergeable_state, is_conflict, ...}`. |
| `github_resolve_pr_for_sha(owner, repo, sha, options)` | Resolve the PR for a commit SHA, preferring payload `pull_requests[]` and falling back to `repos.commit_pulls`. |
| `github_extract_mentions(body)` | Pure string parse of `@handle command args...` mentions in a body. |
| `actions_runner_registration_token(scope, options)` | Create a self-hosted runner registration token (`scope` is `{org}` or `{owner, repo}`). |
| `actions_runner_generate_jitconfig(scope, name, runner_group_id, labels, options)` | Generate a stateless single-use JIT runner config. |
| `actions_runners_list(scope, options)` | List self-hosted runners for a repo or org scope. |
| `oauth_user_device_code(client_id, scope, options)` | Begin the user OAuth device flow. |
| `oauth_user_device_poll(client_id, device_code, options)` | Poll for the device-flow user token. |
| `oauth_user_exchange_code(client_id, code, options)` | Exchange a web-flow code for a user token. |
| `oauth_user_refresh(client_id, refresh_token, options)` | Refresh an expiring `ghu_` user token (rotates the `ghr_` refresh token). |

Token helpers:

| Helper | Purpose |
|---|---|
| `mint_app_jwt(config)` | Mint a GitHub App JWT with Harn `jwt_sign`. |
| `installation_token(config)` | Return a cached installation token or refresh it when stale. |
| `reset_token_cache()` | Clear all cached installation tokens. |
| `invalidate_installation_token(installation_id)` | Remove one cached installation token. |

Common auth options include `installation_token`,
`app_id`/`installation_id`/`private_key_secret`, `api_base_url`, and
`allow_gh_auth_fallback`. Wait helpers accept `poll_interval_ms`, `timeout_ms`,
and `max_attempts`; `max_attempts` wins over wall-clock timeout to keep tests
deterministic.

## GitHub App setup

Create a GitHub App and install it into the target account or repository set.
Record the App ID and Installation ID, configure a webhook secret, then store
the private key PEM in a Harn SecretProvider. Do not commit real GitHub App
private keys or webhook secrets.

Inbound webhooks must include GitHub's `X-GitHub-Event`,
`X-GitHub-Delivery`, and `X-Hub-Signature-256` headers. The connector verifies
the signature against the raw request body with `signing_secret`.

Managed ingress hosts can pass the webhook secret by value as `signing_secret`
or by secret-provider alias through `signing_secret_id`,
`secret_ids.signing_secret`, or `config.secrets.signing_secret`.

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

For local fixture tests only, `private_key_pem` can be passed inline.
Production setup should use `private_key_secret` so Harn resolves the PEM
through `secret_get`.

Required GitHub App permissions depend on the method:

| Methods | GitHub App permission |
|---|---|
| Issue helpers and issue comments | Issues read/write, or Pull requests read/write when acting on PRs. |
| PR read helpers, diffs, files, and reviews | Pull requests read. |
| PR merge, safe merge, auto-merge, and review comments | Pull requests write; protected branches may also require administrator or bypass permissions. |
| Repository content and release helpers | Contents read. |
| Repository content write helpers and `git.create_commit` | Contents write. Pass `github_author_choice` from `std/disclosure` to enforce `author_mode`. |
| `git.delete_ref` | Contents write. |
| Branch protection helpers | Administration read. |
| Actions dispatch | Actions write. |
| Actions run and log reads | Actions read. |
| Self-hosted runner reads (list/get/labels.list/downloads) | Repo `administration:read` or org `organization_self_hosted_runners:read`. |
| Self-hosted runner writes (registration/remove tokens, JIT config, delete, label add/replace/remove, runner groups) | Repo `administration:write` or org `organization_self_hosted_runners:write`. |
| Check run create/update | Checks read/write. |
| `api_call` and `graphql` | Whatever the endpoint, query, or mutation requires. |

The connector signs a GitHub App JWT with Harn `jwt_sign`, exchanges it for an
installation access token, caches that token until its refresh window, and
invalidates the cache after a `401` before retrying once.

Callers that already have an installation token can pass `installation_token`.
For local development only, callers may pass `allow_gh_auth_fallback: true`.
When enabled and no installation credentials are present, the connector uses an
explicit `gh_token`, `GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth token`.

## Operational notes

- Webhook normalization rejects missing, unsupported, or invalid signatures.
- Webhook signing secrets may be supplied directly for local tests or resolved
  from the active Harn SecretProvider.
- Outbound calls use GitHub App installation tokens or a caller-provided
  installation token. The `oauth.user.*` methods add a separate
  user-to-server flow (device and web-flow) for "connect your GitHub account";
  they post to github.com, not the REST API host, and do not affect the App
  flow that drives webhooks. `ghu_` user tokens last 8h and `ghr_` refresh
  tokens 6 months; both rotate on refresh, so persist the returned
  `refresh_token`.
- Outbound HTTP dispatch uses Harn's shared connector policy layer for request
  envelopes, retries, rate-limit header extraction, and JSON parse categories.
- GitHub primary rate-limit responses with short reset windows are retried
  once. Longer waits return `rate_limited` instead of sleeping in CI or webhook
  paths.
- Generic retries do not replay `POST` or `PATCH` requests unless the caller
  supplies `idempotency_key` or opts into `retry_unsafe`.
- Author-mode-aware commit and PR write helpers accept `github_author_choice`
  from `std/disclosure`. Human commit mode sends the selected human
  `commit_author` and appends actor-chain trailers. Bot mode requires GitHub
  App installation auth and omits custom author/committer fields so GitHub
  uses the App `[bot]` identity. Human PR creation requires user auth because
  GitHub assigns PR authorship from the authenticated identity.
- Outbound errors carry deterministic `category` values for typed callers:
  `auth`, `permission`, `rate_limit`, `branch_protection`, `merge_queue`,
  `checks_pending`, `checks_failed`, `validation_failed`,
  `restricted_commit_author`, `network`, and `schema_drift`.
- The connector exposes a focused REST/GraphQL surface rather than vendoring a
  generated GitHub SDK.

## Development

Install the pinned Harn CLI from crates.io:

```sh
cargo install harn-cli --version "$(cat .harn-version)" --locked
harn --version
```

Run the local CI equivalent:

```sh
harn install
harn check src
harn lint src
harn fmt --check src tests
harn connector check .
for test in tests/*.harn; do
  harn run "$test" || exit 1
done
```

`harn connector check .` runs the deterministic webhook fixtures declared in
`harn.toml`, including supported event variants and a signature rejection case.
The `tests/fixtures/webhooks/` payloads are synthetic compatibility fixtures;
they should stay free of live GitHub secrets or private repository data.

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
heading match, reruns the Harn connector gate, performs a clean consumer smoke,
and creates or updates the GitHub Release from the matching changelog section.

## License

Dual-licensed under MIT and Apache-2.0.

- [LICENSE-MIT](./LICENSE-MIT)
- [LICENSE-APACHE](./LICENSE-APACHE)
