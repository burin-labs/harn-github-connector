# Safety model

The connector turns provider-specific GitHub behavior into small contracts an
agent workflow can reason about. The goal is not to hide GitHub. It is to make
identity, freshness, absence, retries, and mutation evidence explicit.

## Requests are named records

High-level helpers accept `harness` plus one closed request record. This keeps
same-shaped values such as owner, repository, branch, tag, SHA, and body from
being swapped at a positional call site. Shared transport and authentication
fields live under `options`.

Operations that observe changing GitHub state put their bounded wait settings
under `polling`. For example, `{polling: {interval_ms: 1000, timeout_ms:
60000}}` cannot be confused with HTTP retry settings under `options`.

The `Harness` is separate because it is host authority, not request data. It
provides HTTP, secrets, time, process, and runtime capabilities that Harn can
audit and constrain.

## Results fail closed

Connector operations return `GithubConnectorResult<T>`. A covered operation
produces either a closed normalized success record or a structured error. It
does not turn malformed provider data into a partial success.

Errors carry a stable `code`, `category`, and `message`, plus an HTTP status
when available. Categories include authentication, permission, rate limits,
branch protection, merge queue, pending or failed checks, validation, network,
and schema drift.

## Mutations use leases

Mutable GitHub state can change between observation and action. Operations such
as auto-merge, signed commits, and release-body edits therefore carry the
observed head, tag, or release identity. The connector rechecks that identity
immediately before the write and returns a stale-state error on mismatch.

This is optimistic concurrency control: the workflow may retry from a fresh
read, but it may not silently apply an old decision to new state.

## Absence must be proven

A `404` can mean missing, private, or forbidden. Exact file and release lookups
report `state: "absent"` only after the same credential proves repository
access. Authentication, permission, and transport failures remain errors.

## Retries preserve intent

The shared connector policy handles request envelopes, JSON errors, rate-limit
headers, and bounded retry timing. Safe reads may retry. `POST` and `PATCH`
requests are not replayed unless the caller supplies an idempotency key or
explicitly enables `retry_unsafe`.

Short primary-rate-limit resets may be retried once. Longer waits return
`rate_limited` instead of sleeping inside a webhook or CI job.

## Identity is explicit

GitHub App authentication produces the installed App identity. User OAuth
produces a human identity. Author-aware commit and pull-request helpers accept
the disclosure contract chosen by the host. Bot commits omit custom author and
committer fields so GitHub uses the App bot identity. Human pull requests
require user authentication because GitHub derives authorship from the token.

## GitHub policy stays authoritative

Repository roles, organization policy, rulesets, merge queues, required
reviews, check requirements, and enterprise controls belong to GitHub. The
connector normalizes the evidence needed by orchestration and exposes
permission failures without claiming that every account tier supports every
operation.

This boundary also generalizes to other forges: keep provider-neutral workflow
intent and evidence in Harn, then implement provider-specific authentication,
capability discovery, leases, error mapping, and raw escape hatches in each
connector. Do not force GitLab, Gitea, or another forge into GitHub's exact
resource model.
