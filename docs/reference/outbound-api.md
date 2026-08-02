# Outbound API reference

Use this page to look up methods, helpers, return values, and authentication
options. See [Configure a GitHub App](../how-to/configure-github-app.md) for
setup, [Runtime policy](runtime-policy.md) for retries and errors, and the
[generated API index](../api.md) for exact exported declarations.

## Result contract

Every outbound operation has one fallible boundary. `call(harness, method, args)`
returns `Result<unknown, GithubConnectorError>`; unwrap or narrow the Result
before reading the success value. Prefer a named helper when available because
its return type names the normalized success contract. `call_typed` adds an
explicit runtime schema check when using a dynamic escape hatch.

```harn
import {
  GithubConnectorResult,
  GithubReleaseLookup,
  github_release,
} from "harn-github-connector/default"

const result: GithubConnectorResult<GithubReleaseLookup> = github_release(
  harness,
  "octo-org",
  "octo-repo",
  "v1.2.3",
  auth,
)
if is_err(result) {
  throw unwrap_err(result).message
}
const release = unwrap(result)
```

The default module exports closed records for pull requests, checks, workflow
runs and dispatches, releases, merge queues, mergeability, auto-merge receipts,
commit signatures, and connector errors. These records are importable in
downstream annotations and compose through `GithubConnectorResult<T>`.

## Methods

Call `outbound_methods()` when code needs the supported-method catalog. It is a
direct view of the executable route registry, so discovery and dispatch cannot
drift. The table below groups the same methods for browsing.

| Area | Methods |
| --- | --- |
| Pull requests | `github.pr.list`, `github.pr.create`, `github.pr.view`, `github.pr.edit`, `github.pr.files`, `github.pr.commits`, `github.pr.checks`, `github.pr.merge`, `github.pr.enable_auto_merge`, `github.pr.comment`, `pulls.list`, `pulls.list_with_checks`, `pulls.get`, `pulls.update`, `pulls.create`, `pulls.merge`, `pulls.merge_safe`, `pulls.create_review_comment`, `pulls.get_diff`, `pulls.list_files`, `pulls.list_reviews`, `pull_requests.resolve_mergeable`, `repos.commit_pulls` |
| Actions and checks | `github.actions.workflow_dispatch`, `github.actions.runs`, `github.actions.run`, `github.actions.run_jobs`, `github.actions.run_cancel`, `github.actions.logs`, `actions.workflow_dispatch`, `actions.workflow_runs.list`, `actions.workflow_run.get`, `actions.workflow_run.jobs`, `actions.workflow_run.cancel`, `check_runs.create`, `check_runs.update` |
| Self-hosted runners | `actions.runners.registration_token`, `actions.runners.remove_token`, `actions.runners.generate_jitconfig`, `actions.runners.list`, `actions.runners.get`, `actions.runners.delete`, `actions.runners.downloads`, `actions.runners.labels.list`, `actions.runners.labels.add`, `actions.runners.labels.replace`, `actions.runners.labels.remove`, `actions.runner_groups.list`, `actions.runner_groups.create`, `actions.runner_groups.get`, `actions.runner_groups.update`, `actions.runner_groups.delete` |
| User OAuth | `oauth.user.device_code`, `oauth.user.device_poll`, `oauth.user.exchange_code`, `oauth.user.refresh` |
| Issues | `github.issue.create`, `github.issue.comment`, `issues.create_comment`, `issues.create`, `issues.create_with_template`, `issues.update`, `issues.add_labels` |
| Repository and release data | `github.file.view`, `github.release.view`, `github.release.edit_body`, `github.release.latest`, `github.release.assets`, `github.commit.signature`, `github.branch.protection`, `github.branch.create_signed_commit`, `repos.get_content`, `repos.get_text`, `repos.create_or_update_file`, `repos.put_content`, `repos.delete_file`, `repos.get_latest_release`, `repos.list_release_assets`, `repos.get_branch_protection`, `git.create_commit`, `git.delete_ref` |
| Merge queue | `github.merge_queue.entries`, `github.merge_queue.membership`, `github.merge_queue.enqueue` |
| Raw access | `api_call`, `graphql` |

The namespaced methods above are the canonical automation boundary. Covered
operations return `Ok(closed_normalized_record)` or a typed
`Err({code, category, message, http_status?})`. Do not issue another GraphQL
request or parse the raw REST response for the same operation.

## Method behavior

- `github.pr.enable_auto_merge` and `github.merge_queue.enqueue` require
  `expected_head_oid`. A mismatched lease returns `stale_head` without mutating.
- `github.merge_queue.membership` reports `queued: true` only when GitHub
  returns a `mergeQueueEntry`. An `autoMergeRequest` is reported separately as
  `auto_merge_armed`.
- `github.pr.view` keeps the base PR read when branch-protection administration
  permission is unavailable. Its `branch_protection.available` is `false` and
  retains the structured permission error.
- Canonical PR summaries, details, views, and lists expose `merged_at` and
  `merge_commit_oid`. A PR reported as merged must carry both fields or the
  response fails closed. `github.pr.commits` reads every commit page under one
  stable head lease and returns each commit's message plus normalized signature
  evidence; unsigned commits remain successful `verified: false` evidence. The
  method fails closed rather than claim completeness when GitHub reports more
  than the pull-request endpoint's 250-commit limit. Open-PR test-merge SHAs are
  not exposed as actual merge commit OIDs.
- `github.actions.workflow_dispatch` requires GitHub's returned run id and
  resolves that exact accepted identity; an empty response fails closed
  without polling workflow lists. Dispatch and run records include workflow
  path/id, run attempt, branch, SHA, event, and URL.
  `github.actions.run_cancel` requests cancellation of one exact run;
  `github.actions.runs`, `github.actions.run`, and `github.actions.run_jobs`
  return closed run, job, and step evidence. The run-list envelope uses typed
  `runs`, never GitHub's raw `workflow_runs` payload.
- `github.file.view` requires an exact `ref`, and `github.release.view` requires
  an exact `tag`. They return `state: "found" | "absent"`; a `404` is absence
  only after the same credential proves repository access. Masked private
  resources and transport failures remain `Err`. Exact release views include
  the release id, tag-ref object, and peeled tag target as a mutation lease.
- `github.release.edit_body` accepts that complete lease and re-observes it
  before issuing one body-only metadata update. Stale release ids or tag
  identities fail closed; tags and assets cannot be included in the request.
- `github.commit.signature` returns GitHub's normalized `verified`, `reason`,
  material-presence, and `verified_at` evidence. Unsigned and invalid
  signatures are successful reads with `verified: false`, not transport errors.

## Low-level methods

Use `api_call`, `graphql`, and unnamespaced methods only when no namespaced
method covers the operation. They do not replace a namespaced method.

## Named helpers

| Helper | Purpose |
| --- | --- |
| `pulls_list_with_checks(harness, owner, repo, state, limit, options)` | List pull requests with merge state and CI rollup. |
| `pulls_update(harness, owner, repo, number, edits, options)` | Update the supported pull request fields. |
| `pulls_merge_safe(harness, owner, repo, number, options)` | Merge after checking branch protection. |
| `pulls_enable_auto_merge(harness, owner, repo, number, options)` | Enable auto-merge. Requires `options.expected_head_oid`. |
| `github_pr_commits(harness, owner, repo, number, options)` | Read every commit and signature under one pull request head. |
| `actions_workflow_dispatch(harness, owner, repo, workflow_id, ref, inputs, options)` | Dispatch a workflow. |
| `actions_workflow_runs(harness, owner, repo, options)` | List workflow runs. |
| `actions_workflow_run(harness, owner, repo, run_id, options)` | Fetch one workflow run by id. |
| `actions_workflow_run_jobs(harness, owner, repo, run_id, options)` | List a workflow run's jobs and steps. |
| `actions_workflow_run_cancel(harness, owner, repo, run_id, options)` | Request cancellation of one workflow run. |
| `api_call(harness, path, method, body, options)` | Call one REST endpoint. |
| `repos_get_text(harness, owner, repo, path, ref, options)` | Decode repository file content as UTF-8 text. |
| `repos_get_latest_release(harness, owner, repo, options)` | Fetch the latest release. |
| `repos_list_release_assets(harness, owner, repo, release_id, options)` | List assets for a release id. |
| `github_latest_release(harness, owner, repo, options)` | Fetch the latest release in a stable record. |
| `github_release_assets(harness, owner, repo, release_id, options)` | List release assets. Uses the latest release when `release_id` is absent. |
| `issues_create_with_template(harness, owner, repo, template, vars, options)` | Render a title and body, then create an issue. |
| `github_dispatch_workflow_and_resolve_run(harness, owner, repo, workflow_id, ref, inputs, options)` | Dispatch a workflow and return its run id. |
| `github_dispatch_workflow_and_wait(harness, owner, repo, workflow_id, ref, inputs, options)` | Dispatch a workflow and wait for that run. |
| `github_wait_for_workflow_run(harness, owner, repo, run_id_or_filter, options)` | Wait for an existing workflow run. |
| `github_ensure_auto_merge(harness, owner, repo, pull_number, options)` | Enable auto-merge. Requires `options.expected_head_oid`. |
| `github_wait_for_pr_checks(harness, owner, repo, pull_number_or_ref, options)` | Wait for pull request or commit checks. |
| `github_find_open_pr(harness, owner, repo, options)` | Find the first matching open pull request. |
| `github_close_pr(harness, owner, repo, pull_number, comment, options)` | Close a pull request and post an optional comment. |
| `github_resolve_mergeable(harness, owner, repo, pull_number, options)` | Resolve GitHub's asynchronous mergeable state. |
| `github_resolve_pr_for_sha(harness, owner, repo, sha, options)` | Resolve the pull request for a commit SHA. |
| `github_create_signed_commit(harness, request, options)` | Append file changes under an expected head OID through GitHub's signed commit mutation. |
| `github_release(harness, owner, repo, tag, options)` | Look up one exact release tag. |
| `github_release_edit_body(harness, owner, repo, tag, body, lease, options)` | Replace a release body under its observed release and tag identity. |
| `github_extract_mentions(body)` | Pure string parse of `@handle command args...` mentions in a body. |
| `actions_runner_registration_token(harness, scope, options)` | Create a self-hosted runner registration token. |
| `actions_runner_generate_jitconfig(harness, scope, name, runner_group_id, labels, options)` | Generate a single-use runner configuration. |
| `actions_runners_list(harness, scope, options)` | List self-hosted runners for a repository or organization. |
| `oauth_user_device_code(harness, client_id, scope, options)` | Begin the user OAuth device flow. |
| `oauth_user_device_poll(harness, client_id, device_code, options)` | Poll for the device-flow user token. |
| `oauth_user_exchange_code(harness, client_id, code, options)` | Exchange a web-flow code for a user token. |
| `oauth_user_refresh(harness, client_id, refresh_token, options)` | Refresh a user token and rotate its refresh token. |

## Token helpers

| Helper | Purpose |
| --- | --- |
| `mint_app_jwt(clock, secrets, config)` | Mint a GitHub App JWT with Harn `jwt_sign`. |
| `installation_token(harness, config)` | Return a cached installation token or refresh it when stale. |
| `reset_token_cache(runtime)` | Clear all cached installation tokens. |
| `invalidate_installation_token(runtime, installation_id)` | Remove one cached installation token. |

Common auth options include `installation_token`,
`app_id`/`installation_id`/`private_key_secret`, `api_base_url`, and
`allow_gh_auth_fallback`. Wait helpers accept `poll_interval_ms`, `timeout_ms`,
and `max_attempts`; `max_attempts` wins over wall-clock timeout to keep tests
deterministic.
