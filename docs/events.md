# Webhook event reference

This page is the stable inbound event contract. Fields not listed here remain
available under `raw` and may change with GitHub's payload.

## Supported events

The connector accepts these `X-GitHub-Event` values:

| Event | Topic prefix |
| --- | --- |
| `issues` | `github.issues` |
| `pull_request` | `github.pull_request` |
| `issue_comment` | `github.issue_comment` |
| `pull_request_review` | `github.pull_request_review` |
| `push` | `github.push` |
| `workflow_run` | `github.workflow_run` |
| `deployment_status` | `github.deployment_status` |
| `check_run` | `github.check_run` |
| `check_suite` | `github.check_suite` |
| `status` | `github.status` |
| `merge_group` | `github.merge_group` |
| `installation` | `github.installation` |
| `installation_repositories` | `github.installation_repositories` |
| `release` | `github.release` |

When GitHub supplies an action, the complete topic is
`github.<event>.<action>`.

## Common fields

| Field | Meaning |
| --- | --- |
| `provider` | Always `github`. |
| `event` | The GitHub event name. |
| `topic` | The normalized event topic. |
| `reaction_topics` | Zero or more semantic reaction topics. |
| `action` | GitHub's action when present. |
| `delivery_id` | `X-GitHub-Delivery`; also the deduplication key. |
| `installation_id` | GitHub App installation ID when present. |
| `repository` | GitHub's repository object. |
| `repo` | `{owner, name, full_name}`. |
| `source_refs` | Provider-neutral repository, resource, and URL references. |
| `triage_event` | `harn.triage_event.v1` for issue and review work. |
| `job_event` | `harn.job_event.v1` for jobs and merge-queue work. |
| `raw` | The original parsed GitHub payload. |

Issue, pull-request, and comment bodies may also produce `mention`. It contains
parsed `@handle command args...` candidates and source metadata. Downstream
code must select a candidate using the bot's configured identity.

## Automation fields

- `github.pull_request.<action>` promotes PR number, head and base refs and
  SHAs, draft and merge state, and labels.
- `github.check_run.<action>` promotes check, suite, and PR IDs; head SHA;
  name; status; and conclusion.
- `github.check_suite.<action>` promotes suite and PR IDs, head SHA, status,
  and conclusion.
- `github.workflow_run.<action>` promotes run, workflow, suite, and PR IDs;
  head SHA; status; and conclusion.
- `github.status` promotes status ID, head SHA, state, context, and target URL.
- `github.merge_group.<action>` promotes group ID; head and base refs and SHAs;
  and pull-request numbers.
- `github.push` promotes refs, before and after SHAs, commits, size, and branch
  creation, deletion, and force-push flags.
- `github.installation.<action>` promotes account, state, suspension,
  revocation, and repositories.
- `github.installation_repositories.<action>` promotes account, state,
  selection, and added and removed repositories.
- `github.release.<action>` promotes release ID, tag, name, draft and
  prerelease state, target, publication time, and assets.

## Reaction topics

- `github.reaction.ci_failure` means a check, workflow run, or commit status
  ended in a failure or error state.
- `github.reaction.merge_conflict` means a pull request reported
  `mergeable_state: "dirty"`.

Dashboard envelopes include the source URL, timestamp, actors, summary,
priority, status, deduplication key, related references, and proposed actions.
Proposed provider writes carry `requires_approval: true`; the host decides
whether to execute them.
