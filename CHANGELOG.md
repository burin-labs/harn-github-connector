# Changelog

## 0.1.0 - 2026-04-29

- Ship the first production-ready pure-Harn GitHub connector release.
- Implement connector contract v1 exports, NormalizeResult v1 webhook
  normalization, and deterministic connector fixtures for supported GitHub
  webhook events.
- Implement outbound GitHub REST/GraphQL methods with direct installation-token
  support and GitHub App JWT installation-token rotation.
- Support managed-ingress webhook secret aliases through Harn `secret_get`.
- Pin local and CI verification to the published `harn-cli` 0.7.48 release.
