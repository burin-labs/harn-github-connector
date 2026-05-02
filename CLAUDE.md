# CLAUDE.md - harn-github-connector

Pure-Harn GitHub App connector package for inbound webhooks and outbound REST/GraphQL calls.

Shared Harn connector authoring rules live in the canonical guide:

- https://github.com/burin-labs/harn/blob/main/docs/src/connectors/authoring.md

Keep this file limited to provider-specific notes and local hazards. Add shared connector guidance
to the Harn guide first.

## Provider Notes

- Webhook verification uses `X-Hub-Signature-256` over the raw request body with the configured
  GitHub App webhook secret.
- Outbound installation-token flow depends on GitHub App credentials: app id, private key, and
  installation id. Keep token refresh behavior aligned with GitHub App expiry semantics.
- A typed `github-sdk-harn` would be a separate package; this connector should not grow generated
  REST endpoint definitions.
