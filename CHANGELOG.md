# Changelog

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

- Ship the first production-ready pure-Harn GitHub connector release.
- Implement connector contract v1 exports, NormalizeResult v1 webhook
  normalization, and deterministic connector fixtures for supported GitHub
  webhook events.
- Implement outbound GitHub REST/GraphQL methods with direct installation-token
  support and GitHub App JWT installation-token rotation.
- Support managed-ingress webhook secret aliases through Harn `secret_get`.
- Pin local and CI verification to the published `harn-cli` 0.7.48 release.
