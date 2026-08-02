# Webhook reference

Use this page to look up accepted events and normalized fields. See
[Configure a GitHub App](../how-to/configure-github-app.md) to set up webhook
delivery.

## Supported events

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

## Normalized payload

The connector keeps the GitHub payload under `raw` and copies stable fields to
the top-level event:

| Field | Notes |
| --- | --- |
| `provider` | Always `github`. |
| `event` | GitHub event kind, such as `pull_request` or `merge_group`. |
| `topic` | `github.<event>` or `github.<event>.<action>`. |
| `reaction_topics` | Semantic `github.reaction.*` topics derived from the payload. |
| `action` | GitHub payload action when present. |
| `delivery_id` | `X-GitHub-Delivery`; also used for the dedupe key. |
| `installation_id` | GitHub App installation id when present. |
| `repository` / `repo` | Raw repository plus normalized `{owner, name, full_name}`. |
| `source` / `source_refs` | Source links with repository names and resource ids. |
| `mention` | Parsed `@handle command args...` directives from issue, pull request, and comment bodies. |
| `triage_event` | `harn.triage_event.v1` envelope for issues, PRs, comments, and reviews. |
| `job_event` | `harn.job_event.v1` envelope for checks, runs, releases, pushes, deployments, and merge queue events. |
| `raw` | Original GitHub payload for fields not promoted by the connector. |

The `triage_event` and `job_event` records include source URLs, timestamps,
actors, summaries, proposed actions, status, dedupe keys, privacy flags,
related sources, and action requests. Every write request has
`requires_approval: true`. The host approves and executes it.

## Topics

Merge Captain and release consumers subscribe to these topics:

| Topic | Promoted fields |
| --- | --- |
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

## Reaction topics

| Topic | Emitted when |
| --- | --- |
| `github.reaction.ci_failure` | A `check_run`, `check_suite`, `workflow_run`, or `status` payload ends in a failure or error state. |
| `github.reaction.merge_conflict` | A pull request payload reports `mergeable_state: "dirty"`. |
