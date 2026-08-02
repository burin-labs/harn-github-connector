# Module ownership reference

Use this page to find the module that owns a connector behavior. Keep each
semantic decision in one module and expose it through [`src/lib.harn`](../../src/lib.harn).

| Module | Ownership |
| --- | --- |
| [`lib.harn`](../../src/lib.harn) | Public package facade and typed convenience functions. |
| [`dispatch.harn`](../../src/dispatch.harn) | Executable method catalog, generic `call`, typed `call_typed`, and method dispatch. |
| [`orchestration.harn`](../../src/orchestration.harn) | Cross-endpoint workflow dispatch, CI monitoring, pull-request lookup, closure, and mergeability flows. |
| [`client.harn`](../../src/client.harn) | Authentication, outbound policy, HTTP transport, pagination, installation-token caching, and rate-limit handling. |
| [`endpoints.harn`](../../src/endpoints.harn) | REST and GraphQL endpoint derivation plus public-HTTPS validation. |
| [`contracts.harn`](../../src/contracts.harn) | Closed records returned by the public API. |
| [`actions.harn`](../../src/actions.harn) | Workflow runs, jobs, logs, cancellation, and self-hosted runners. |
| [`pull_requests.harn`](../../src/pull_requests.harn) | Pull-request reads, edits, checks, merges, comments, and branch-protection evidence. |
| [`pull_request_models.harn`](../../src/pull_request_models.harn) | Conversion from GitHub responses to closed pull-request and check records. |
| [`merge_queue.harn`](../../src/merge_queue.harn) | Merge-queue entries, membership, and enqueue leases. Auto-merge holds stay with pull-request mutations. |
| [`mergeability.harn`](../../src/mergeability.harn) | Bounded polling for GitHub's asynchronous mergeability state. |
| [`commits.harn`](../../src/commits.harn) | Pull-request commit evidence, signature validation, commit-to-PR lookup, and atomic signed commits. |
| [`repository.harn`](../../src/repository.harn) | Repository identity, access checks, exact branch heads, and exact file reads. |
| [`releases.harn`](../../src/releases.harn) | Release lookup, leased metadata edits, and asset listing. |
| [`issues.harn`](../../src/issues.harn) | Issue creation, comments, and template rendering. |
| [`writes.harn`](../../src/writes.harn) | Small write transports after author identity has been resolved. |
| [`authoring.harn`](../../src/authoring.harn) | Human or GitHub App author identity in write bodies. |
| [`rest_methods.harn`](../../src/rest_methods.harn) | Small direct REST and GraphQL operations that do not justify a domain module. |
| [`oauth.harn`](../../src/oauth.harn) | GitHub user-to-server OAuth operations. |
| [`webhooks.harn`](../../src/webhooks.harn) | Inbound signature verification, binding lifecycle, and normalization. |
| [`webhook_sources.harn`](../../src/webhook_sources.harn) | Webhook source configuration and delivery metadata. |
| [`webhook_dashboard.harn`](../../src/webhook_dashboard.harn) | Dashboard projections for webhook state. |
| [`worktree_commit.harn`](../../src/worktree_commit.harn) | Atomic commits built from a local worktree. |
| [`publish_cli.harn`](../../src/publish_cli.harn) | Command-line adapter for publishing a worktree commit. |
| [`errors.harn`](../../src/errors.harn) | Stable connector error records and constructors. |
| [`validation.harn`](../../src/validation.harn) | Shared input validation. |
| [`collections.harn`](../../src/collections.harn), [`text.harn`](../../src/text.harn) | Small shared collection and text functions. |

Add a method to the catalog in [`dispatch.harn`](../../src/dispatch.harn) only
when the generic `call` API must expose it. Keep request construction and
response normalization in the domain module named above.

Provider contracts:

- [GitHub pull-request REST API](https://docs.github.com/en/rest/pulls/pulls)
- [GitHub pull-request GraphQL types](https://docs.github.com/en/graphql/reference/objects#pullrequest)
- [Git commit REST API](https://docs.github.com/en/rest/git/commits)
- [GitHub Actions REST API](https://docs.github.com/en/rest/actions)
