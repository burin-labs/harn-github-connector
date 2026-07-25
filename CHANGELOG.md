# Changelog

## 0.4.0 - 2026-07-25

- Add typed `github.pr.edit` and `pulls.update` operations for a closed set of
  editable pull-request fields, with validation before network dispatch and a
  normalized edit result.
- Add typed `github.branch.create_signed_commit` dispatch and
  `github_create_signed_commit` helper. It uses GraphQL
  `createCommitOnBranch`, requires an expected head OID, omits custom commit
  identity fields, and fails closed unless GitHub reports a valid signature
  made with its signing key.
- Add semantic `reaction_topics` to normalized webhook payloads. Failed
  check/workflow/status events now emit `github.reaction.ci_failure`, and dirty
  pull requests emit `github.reaction.merge_conflict`, so hosted captains can
  subscribe to stable reaction topics instead of re-deriving GitHub predicates.
- Fix `activate` corrupting caller-supplied binding ids: a misplaced paren
  appended the binding index to every id (e.g. `primary` -> `primary0`), so a
  webhook carrying `metadata.binding_id` could not resolve its binding-scoped
  signing secret and was rejected with `missing_secret`. Ids are now preserved
  verbatim and the index suffix only applies to the generated `binding-N`
  fallback.
- Fix `actions.runners.generate_jitconfig` silently POSTing a placeholder
  `{error: "missing_name"}` body when `name` was omitted; it now returns a
  `schema_drift` error before issuing any request.
- Route `pulls.merge_safe` branch-protection lookups through the shared
  `__github_branch_protection_raw` helper instead of re-implementing the
  request and 404 handling, keeping protection semantics in one place.
- Add author-mode-aware write paths for `pulls.create`,
  `repos.create_or_update_file`/`repos.put_content`, `repos.delete_file`, and
  `git.create_commit`. `author_mode=human` applies the supplied
  `github_author_choice` commit author and trailers; `author_mode=bot` requires
  GitHub App installation auth and omits custom author/committer fields so
  GitHub uses the App `[bot]` identity. Restricted author responses now return
  `restricted_commit_author`; other 422 validation responses return
  `validation_failed`.
- Expose `github.app.installation_token` as an outbound `call` method. It
  returns the installation bearer token the connector already resolves
  internally — self-minted from `app_id` + `installation_id` +
  `private_key_pem`/`private_key_secret` (RS256 JWT exchange), or passed through
  in direct/`gh-auth` modes — as `{token, token_mode, installation_id,
  api_base_url}`. This lets an orchestrator (e.g. harn-cloud) obtain a token for
  its own git operations without re-implementing JWT minting. No new privilege:
  the caller must already hold the App credentials to mint.

- Added typed release lookup by exact tag so automation no longer assembles raw GitHub API paths.
- Explicit `allow_gh_auth_fallback` policy now overrides ambient environment configuration, so strict in-process callers can guarantee that connector authentication never spawns the GitHub CLI.
- Typed pull-request listing now owner-qualifies bare head branches, implements merged-state filtering over GitHub's closed-PR REST contract, rejects unsupported states before I/O, and promotes GraphQL protocol errors instead of returning false successes.
- Workflow dispatch waits now snapshot matching run IDs before dispatch, select
  only one unseen exact run when GitHub returns no ID, and fail closed with a
  typed `ambiguous_dispatch` result when multiple unseen runs match.
- Added a durable workflow dispatch boundary that returns the exact accepted run
  identity before terminal monitoring, while preserving typed dispatch, lookup,
  and ambiguity failures.
- Workflow dispatch identity receipts now preserve the exact run source SHA, branch, event, URL, and timestamps returned by GitHub, and expose a typed helper for fetching one run.
- Workflow dispatch identity resolution now hydrates exact run metadata before reporting success, including when GitHub returns a run ID before the run is observable.
- Added canonical closed typed GitHub orchestration methods for pull request
  create/list/files/comments, expected-head auto-merge, merge queue evidence,
  exact workflow runs/jobs, commit signatures, and exact file/release lookups.
  PR reads now preserve unavailable branch-protection enrichment, queue membership
  no longer treats armed auto-merge as queued, and masked 404s fail closed unless
  repository access independently proves absence.
- Added a pure-Harn worktree-to-signed-commit adapter, exported as
  `harn-github-connector/worktree`, so consumers stop assembling
  `createCommitOnBranch` payloads themselves. It derives typed additions and
  deletions from an exact Git state (worktree or index) without touching the
  caller's index, preserves exact blob bytes including binary, maps renames to
  delete-old plus add-new, takes the branch lease, and returns one receipt binding
  repository, branch, base, commit oid, changed paths with content digests, and
  GitHub's signature evidence. File modes are gated before any network request:
  editing a path already tracked at `100755` is published (the mutation preserves
  the base tree entry's mode), while a new executable, a mode change, and any
  symlink or submodule entry fail closed. Signed-commit additions now also accept
  genuinely empty file contents instead of failing as if the field were missing.
- Added stable typed pull-request commit pagination with per-commit signature evidence, canonical merged PR timestamp/OID fields, and a closed typed workflow-run list envelope for release automation. CI and release validation now execute the deterministic in-process named-test suite in addition to executable smoke pipelines.
- Workflow dispatch now fails closed when GitHub omits the returned run id,
    preserves exact workflow/source/run-attempt identity, and exposes typed
    cancellation for an exact workflow run.
- Export the connector's normalized GitHub records and use one typed `Result`
  boundary for dynamic calls, named helpers, mergeability, and workflow dispatch.
- Added a typed workflow-run jobs API that returns GitHub's canonical jobs and
  steps payload, validates run identifiers, and supports bounded filter and
  pagination options.

- Add GitHub Actions self-hosted runner management methods supporting both repo
  (`owner`+`repo`) and org (`org`) scope: `actions.runners.registration_token`,
  `remove_token`, `generate_jitconfig` (stateless single-use), `list`, `get`,
  `delete`, `downloads`, `labels.list/add/replace/remove`, and
  `actions.runner_groups.list/create/get/update/delete`. Mutating methods need
  repo `administration:write` or org
  `organization_self_hosted_runners:write`.
- Add a CPU-only `@handle command args...` mention extractor to
  `normalize_inbound`. Issue, PR, and comment payloads gain a `mention` block
  (`{candidates, actor, command, handle, rest, issue_number?, comment_id?,
  html_url?}`); the `github_extract_mentions(body)` helper exposes the parser.
- Add user-to-server OAuth methods `oauth.user.device_code`,
  `oauth.user.device_poll`, `oauth.user.exchange_code`, and
  `oauth.user.refresh` (plus matching helpers) for "connect your GitHub
  account". `ghu_`/`ghr_` tokens rotate on refresh. Adds the `oauth`
  connector capability.
- Add `pull_requests.resolve_mergeable` (and `github_resolve_mergeable`) to
  resolve a PR's async `mergeable`/`mergeable_state` with bounded polling,
  surfacing `is_conflict`.
- Add `repos.commit_pulls` and `github_resolve_pr_for_sha(owner, repo, sha)`
  to recover the PR for a commit SHA, preferring payload `pull_requests[]` and
  falling back to the commit→pulls lookup for forks and `status` events.
- Tighten repo-local agent guidance and README runtime notes.
- Add latest-release and release-asset helpers for release automation.
- Add `api_call` as a raw REST compatibility escape hatch.
- Add source refs plus `harn.triage_event.v1` and `harn.job_event.v1`
  dashboard envelopes for GitHub webhook payloads.
- Add release webhook normalization and deterministic dashboard fixture coverage.
- Return explicit `missing_scopes` and `inaccessible_resource` errors for
  GitHub permission and access failures.

## 0.3.0 - 2026-05-06

- Add repository automation helpers for typed PR, Actions, merge queue, issue,
  branch-protection, and repository-content workflows.
- Add orchestration helpers for dispatching and waiting on workflows, waiting
  for PR checks, enabling auto-merge, finding open PRs, and closing PRs.
- Add deterministic conformance coverage for the new repository automation and
  orchestration helper surfaces.
- Add connector CI and release workflows, plus a scheduled Harn runtime bump
  workflow.
- Bump the verified Harn runtime to `harn-cli` 0.7.60.

## 0.2.0 - 2026-05-02

- Add typed normalized webhook payloads and stable `github.<event>[.<action>]`
  topics for Merge Captain and release workflow consumers.
- Add inbound support for `check_suite`, `status`, `merge_group`,
  `installation`, and `installation_repositories` webhooks.
- Promote PR/check/workflow/status/merge-group identifiers such as
  `pull_request_number`, `head_sha`, `base_ref`, `run_id`, `check_id`,
  `check_suite_id`, and `merge_group_id`.
- Promote installation suspension and revocation fields so hosted consumers can
  pause affected captains cleanly.
- Add deterministic replay fixtures and connector contract coverage for the new
  event families.
- Document stable GitHub webhook topics and promoted payload fields.

- Add typed outbound methods for PR list/view/checks/merge/comment, Actions
  logs, merge queue entries/enqueue, issue create/comment, and branch
  protection discovery.
- Add deterministic outbound error categories and a gated local-development
  `gh auth` token fallback.
- Add mocked typed-outbound conformance coverage for green, pending, failing,
  dirty, queued, and merged PR states.

## 0.1.0 - 2026-04-29

- Ship the first pure-Harn GitHub connector release.
- Implement connector contract v1 exports, NormalizeResult v1 webhook
  normalization, and deterministic connector fixtures for supported GitHub
  webhook events.
- Implement outbound GitHub REST/GraphQL methods with direct installation-token
  support and GitHub App JWT installation-token rotation.
- Support managed-ingress webhook secret aliases through Harn `secret_get`.
- Pin local and CI verification to the published `harn-cli` 0.7.48 release.
