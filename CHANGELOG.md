# Changelog

## Unreleased

## 0.8.6 - 2026-08-15

- Expose each GitHub Actions run's `display_title` in the typed workflow-run
  contract. Durable orchestrators can now identify explicitly correlated
  continuation runs without guessing from timestamps or run numbers.

## 0.8.5 - 2026-08-15

- Prove an exact pull request head through GitHub Actions when an installation
  token cannot read the Checks rollup through either REST or GraphQL. The
  connector keeps only the newest run for each workflow and event, rejects
  incomplete pages or changed heads, and feeds the result through the same
  typed check evaluator. Unrelated authorization failures still fail closed.

## 0.8.4 - 2026-08-15

- Read an exact pull request's status rollup through GitHub GraphQL when an
  installation token has Pull Requests access but not the wider Checks scope.
  The adapter verifies the requested head SHA and projects both check runs and
  legacy status contexts into the existing typed receipt. Other permission
  failures still fail closed, so private repositories no longer require a
  broader GitHub App grant just to prove a merged update is green.

## 0.8.3 - 2026-08-11

- Let leased pull-request upserts wait through GitHub's brief branch-to-pull
  propagation lag. Callers identify the exact `previous_head_oid` that was just
  replaced; only reads of that head are retried, while third-party heads,
  changed head/base identity, provider failures, and an exhausted bounded wait
  still fail closed without a pull-request mutation.
- Retry a contended ref claim's read-back through GitHub's bounded propagation
  window. A newly-created custom ref can return 404 briefly after its atomic
  create has already made a competing claim fail with 422; the connector now
  reports the holder instead of misclassifying that race as an unreadable API
  failure.
- Model omitted GitHub-authorship fields as optional record fields in package
  regressions, keeping the suite valid under newer Harn strict checking.

## 0.8.2 - 2026-08-05

- Stop `github_commit_worktree` closing the pull request it rewrites.
  `createCommitOnBranch` can only append to a branch's current head, so a
  rewrite has to put a branch at the base commit before the commit exists — and
  doing that to the target left it resting on exactly the base for the length of
  the mutation. GitHub reads a pull request whose head equals its base as having
  nothing to merge and closes it. Observed, not predicted: on
  burin-labs/harn-bump-fleet#697 `head_ref_force_pushed` and `closed` landed in
  the same second, and the pull request stayed closed with its head frozen at
  the base while the branch itself moved on to the signed commit. Reopening does
  not restore the checks, reviews, or auto-merge arming that closing dropped.

  A rewrite now commits on a short-lived staging branch and moves the target
  exactly once, from the head `expected_branch_oid` named to the finished
  commit — the same single ref update `git push --force-with-lease` performs,
  which a pull request survives as an ordinary force-push. The lease is re-read
  immediately before that write, because the commit is made in between and a
  REST force update carries no compare-and-swap of its own; that window is one
  round trip, and is the narrowest the API allows. Receipts are unchanged and
  still name the caller's branch. Callers that create a branch, or whose branch
  already sits at the base, are unaffected — neither can have an open pull
  request to lose.

## 0.8.1 - 2026-08-05

- Let `github_commit_worktree` lease the branch it resets. `reset_branch` is a
  force, and the only lease it carried was on the *base*: a caller rewriting a
  pull-request head to make it signable would discard whatever had landed on
  that branch since the head it decided to rewrite. `expected_branch_oid` is the
  missing half, and it means what `git push --force-with-lease=<branch>:<oid>`
  means — proceed only while the branch is still where the caller left it.
  Anything else is `stale_head` and nothing is written: moved on, already reset
  to the base by a peer, or deleted outright, which is refused rather than
  answered by recreating the branch. Optional, because a branch this call
  creates from scratch has no head to lease, so existing callers are unaffected.

- Read the ref back when `github_claim_ref` is refused with 409, not only 422.
  GitHub answers a taken ref with 422 today — verified against the live API —
  and its create contract documents 409 for the same case. Only the read-back
  can tell contention from a bad ref name or a missing object, so the status
  merely decides whether that read is worth a round trip; treating a documented
  one as an unknown failure reported a held lock as unreadable, which is the one
  answer a caller cannot act on. Any other status still fails without a second
  request, because a 500 is not evidence of a holder.

## 0.8.0 - 2026-08-04

- Let `github_claim_ref` mint its own payload. A lock has nothing to point at
  when it is taken: the work it guards has not happened yet. Passing `payload`
  instead of `oid` has the connector create a parentless commit carrying the
  caller's message, reusing the tree at `base_ref`, and claim the ref with it —
  so a caller gets "who holds this, and since when" out of the existing
  `holder_headline` without handling a tree. Parentless on purpose: a lock is a
  label, not history, and a payload with the base commit as its parent could be
  carried into the branch it was only ever describing. `oid` is now optional;
  callers that pass one are unaffected.

- Add `github_release_ref`. GitHub's ref delete has no compare-and-swap, so the
  only thing separating "release my lock" from "delete whoever holds it now" is
  reading the ref first: the delete is refused when the ref has moved, and an
  absent ref is reported as the intended end state rather than an error, so a
  release that retries after a partial failure can finish. An unreadable ref
  stays an error, because a 500 is not evidence a lock is gone.

## 0.7.0 - 2026-08-04

- Add `github_claim_ref`, an atomic ref claim. `POST /git/refs` is the only
  GitHub primitive that serializes across machines, and the connector exposed
  `git.delete_ref` and `git.create_commit` but no way to create a ref, so a
  caller wanting a cross-machine lock had no typed path to one. Contention is
  returned as an outcome rather than an error: a lost claim carries the holder's
  oid and the first line of its commit message, which is what lets a payload
  commit answer *who* holds the ref. GitHub spends one 422 on "taken", "no such
  object", and "bad ref name", so the claim reads the ref back to tell them
  apart and only reports contention when the ref really resolves.

- Run the release gate against `main` before a tag exists. `release.yml` is
  triggered by the tag push, so the version match, the CHANGELOG heading, and
  `harn package verify` all run against an object that is already immutable and
  signed; a gate that fails there burns the version and strands the tag, which
  is how v0.6.1 and v0.6.7 ended up with no release behind them. The preflight
  runs the same `scripts/check-release.sh` on every push to `main`, deriving the
  prospective tag from `harn.toml`, so whether a commit is releasable is known
  before anyone reaches for `git tag`.

- Have the release gate write a package verification receipt and upload it from
  the release job. The human-readable summary names the failing check and
  nothing else, so the failed v0.6.7 release reported `package tests: fail` with
  no indication of which of 121 tests failed; recovering it meant reproducing
  the job's environment locally. CI already kept this receipt — the release path
  now keeps the same one at the same path.


- Replace long positional helper calls with one closed request record after
  `harness`. Repository identity, resource identity, mutation leases, payloads,
  and client policy are now named at every high-level call site. The old
  positional signatures were removed instead of retained as compatibility
  shims.
- Split the former 8,695-line package module into focused API, contract,
  transport, operation, webhook, pull-request, Actions, OAuth, repository,
  release, issue, and commit modules. The default export is a public facade;
  internal modules depend on their owning layers rather than importing the
  facade back into the implementation.
- Make `GithubClientOptions` the typed owner of authentication, transport, and
  retry policy. Request records carry it under `options`; workflow, check, and
  mergeability monitors carry a separate `GithubPollingPolicy` under
  `polling`. Adapters normalize each record once at its owning boundary.
- Point the provider contract at its focused webhook module so connector
  discovery does not compile the complete outbound API surface.
- Require Harn 0.10.53. That release compiles exported schemas into separate
  addressable initializers, allowing this package's complete typed facade to
  load without a 64 KiB bytecode limit.
- Replace the mixed-purpose README with focused setup, webhook reference,
  signed-commit, safety-model, generated API, and contribution pages. Examples
  use the typed request API.

## 0.6.8 - 2026-08-02

- Make the release-gate tests hermetic. The fixture package now owns its own
  Git repository and states the tag-head requirement explicitly instead of
  inheriting it, so the gate reads fixture tags rather than this checkout's.
  The v0.6.7 release run failed on exactly this: the release job exports
  `CHECK_RELEASE_REQUIRE_TAG_HEAD=true` and checks out full history, so the
  fixture resolved the real `v0.6.6` tag and compared it against `HEAD`. Both
  tag-head outcomes now have direct coverage.

## 0.6.7 - 2026-08-02

- Export closed file and latest-release lookup contracts plus named typed
  helpers. Accessible absence remains distinct from masked repositories and
  transport failure. Found and absent variants are discriminated unions, so
  orchestrators neither duplicate GitHub response shapes nor admit a missing
  payload in a found lookup.

## 0.6.6 - 2026-08-02

- Add exact, typed branch-tree comparison and pull-request upsert operations
  for package-backed automation. Upserts lease the expected head, reject
  ambiguous matches, and project a closed created/updated receipt. Pull-request
  create bodies now use an allow-list so caller-only lease or context fields
  cannot leak into GitHub requests.

## 0.6.5 - 2026-08-02

- Add typed branch-head reads and auto-merge suspension under exact pull-request
  and base-branch leases. Ambiguous mutation outcomes are compensated before
  returning, and receipts preserve the prior merge method for deterministic
  restoration by release queue coordinators.
- Preserve the armed auto-merge method in typed pull-request and merge-queue
  observations so coordinators can restore the exact prior intent without
  probing provider-shaped response fields.

## 0.6.4 - 2026-08-02

- Declare Harn 0.10.50 as the package minimum, matching the typed runtime
  boundary used by authentication and worktree publishing instead of
  advertising compatibility with older, incompatible process APIs.

## 0.6.3 - 2026-08-02

- Route the explicit `gh auth token` compatibility fallback through
  `process_run(process, argv)`. Current Harn intentionally exposes process
  effects as typed stdlib functions rather than methods on `HarnessProcess`.
  The connector now compiles and executes this path under Harn v0.10.50.

## 0.6.2 - 2026-08-02

- Fix the GitHub CLI authentication fallback to execute through the typed
  `HarnessProcess.run` contract. Missing local credentials remain a structured
  authentication error instead of failing on the removed generic process API.

## 0.6.0 - 2026-08-02

- Add typed `github.actions.run_rerun` and `actions.workflow_run.rerun`
  operations for retrying one exact workflow run. Invalid run ids and debug
  flags fail before transport, accepted requests return a closed receipt, and
  provider failures retain the connector's typed error contract.

## 0.5.0 - 2026-08-01

- Migrate the connector and its complete test surface to typed `Harness`
  capabilities. Runtime state now flows through `harness.runtime`, HTTP,
  process, filesystem, clock, secrets, and testing access is explicit, and
  legacy smoke entrypoints are named test pipelines so current Harn cannot
  silently skip them.
- Preserve binary-exact worktree publishing tests under Harn's process
  sandbox by constructing fixtures through typed filesystem operations rather
  than shell redirection.
- Add a `harn-github-connector/publish` export: a command-line front end for
  `github_commit_worktree` owning argument parsing, usage text, the changed-path
  summary a CI step appends to its job log, and exit codes that separate a bad
  invocation (`2`) from a failed publish (`1`). Consumers keep only a one-line
  entry file, so a repository adopting the adapter no longer has to write its
  own argument parser. `--no-reset` opts out of force-moving a branch that is
  not already at the base commit.

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
