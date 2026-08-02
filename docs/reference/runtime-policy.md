# Runtime policy reference

Use this page to look up authentication, retry, rate-limit, and error behavior.
See [Configure a GitHub App](../how-to/configure-github-app.md) for setup.

## Authentication

The connector signs a GitHub App JWT, exchanges it for an installation access
token, and caches the token until its refresh window. A `401` invalidates the
cached token before one retry.

Outbound calls use a GitHub App installation token or a caller-provided
`installation_token`. The `oauth.user.*` methods implement a separate user
device and web authorization flow against `github.com`. Persist each returned
`refresh_token` because GitHub rotates it during refresh.

## Webhook verification

Webhook normalization rejects missing, unsupported, and invalid signatures.
Tests can pass a signing secret directly. Hosts read production secrets from
their Harn secret provider.

## Retries and rate limits

Outbound HTTP calls use Harn's connector HTTP policy for request records,
retries, rate-limit headers, and JSON errors.

The connector retries one GitHub primary rate-limit response when its reset
window fits `rate_limit_max_sleep_seconds`. Longer waits return `rate_limited`.

Retries do not replay `POST` or `PATCH` requests without `idempotency_key` or
`retry_unsafe: true`.

## Commit identity

Commit and pull request write helpers accept `github_author_choice` from
`std/disclosure`. Human mode sends the selected `commit_author` and appends
actor trailers. Bot mode requires GitHub App installation authentication and
lets GitHub assign the App's bot identity. Human pull request creation requires
user authentication because GitHub assigns authorship from the authenticated
identity.

## Error categories

Outbound errors use these `category` values:

- `auth`
- `permission`
- `rate_limit`
- `branch_protection`
- `merge_queue`
- `checks_pending`
- `checks_failed`
- `validation_failed`
- `restricted_commit_author`
- `network`
- `schema_drift`
