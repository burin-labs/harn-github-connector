# Changelog

## Unreleased

- Expose `github.app.installation_token` as an outbound `call` method. It
  returns the installation bearer token the connector already resolves
  internally — self-minted from `app_id` + `installation_id` +
  `private_key_pem`/`private_key_secret` (RS256 JWT exchange), or passed through
  in direct/`gh-auth` modes — as `{token, token_mode, installation_id,
  api_base_url}`. This lets an orchestrator (e.g. harn-cloud) obtain a token for
  its own git operations without re-implementing JWT minting. No new privilege:
  the caller must already hold the App credentials to mint.

## 0.4.0 - 2026-06-02

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
