# SESSION_PROMPT.md — harn-github-connector v0

You are picking up the v0 build of `harn-github-connector`, a pure-Harn
GitHub App connector. This file is your self-contained bootstrap.

## Pivot context (60 seconds)

Harn is moving per-provider connectors **out** of its Rust monorepo and
into external pure-Harn libraries under `burin-labs/`. This repo is one
of the four flagship per-provider connectors. The existing Rust impl at
`/Users/ksinder/projects/harn/crates/harn-vm/src/connectors/github/mod.rs`
(1243 LOC) is the behavior spec — port its semantics into pure Harn.

Tracking ticket: [Pure-Harn Connectors Pivot epic
#350](https://github.com/burin-labs/harn/issues/350).

## What this repo specifically delivers

A pure-Harn module that implements the Harn Connector interface and is
loadable by the orchestrator runtime as the `github` provider:

- `pub fn provider_id() -> string` returning `"github"`.
- `pub fn kinds() -> list` returning `["webhook"]`.
- `pub fn payload_schema() -> dict` returning the canonical normalized
  event schema.
- Lifecycle: `pub fn init(ctx)`, `pub fn activate(bindings)`,
  `pub fn shutdown()`.
- `pub fn normalize_inbound(raw) -> dict` — verifies the
  `x-hub-signature-256` HMAC against the raw body using `hmac_sha256` +
  `constant_time_eq`, then normalizes the GitHub event payload.
- `pub fn call(method, args)` — outbound dispatch. Supports both REST
  (`"issues.create_comment"`, `"pulls.list_files"`) and GraphQL
  (`"graphql"` with `{ query, variables }`).
- Installation-token rotation: signs a JWT with the GitHub App private
  key, exchanges it for a short-lived installation access token, caches
  it until ~5 minutes before expiry. **See open question on JWT below.**

## What's blocked

- **[harn#346 (Connector interface contract)](https://github.com/burin-labs/harn/issues/346)** —
  the formal interface isn't accepted yet. Match the function shapes
  listed above; expect tweaks.
- **[harn#345 (Package management v0)](https://github.com/burin-labs/harn/issues/345)** —
  needed for distribution. **Do not cut a v0.1.0 release tag until
  #345 lands.** No sibling SDK dependency for v0, so development isn't
  blocked.
- **[harn#347 (Bytes value type + raw inbound body access)](https://github.com/burin-labs/harn/issues/347)** —
  GitHub webhooks are JSON (UTF-8), so `raw.body_text` works for HMAC
  verification in v0. Revisit when #347 lands.

### Open question — JWT signing for GitHub App installation tokens

GitHub App installation token rotation requires generating an ES256-signed
JWT (RS256 also accepted; ES256 is the modern path). The Harn stdlib
**does not currently expose a JWT signing builtin**.

Two paths to resolve:

1. **Propose a `jwt_sign(alg, claims, private_key) -> string` builtin
   upstream.** This is the right long-term answer; many connectors will
   need it. File a ticket on `burin-labs/harn` referencing this
   `SESSION_PROMPT.md` before starting M3.
2. **Implement ES256 in pure Harn.** Possible (Harn has SHA-256 and
   bigint via stdlib helpers, in principle), but ECDSA over P-256 is a
   non-trivial pure-Harn implementation and creates a larger attack
   surface than a vetted Rust crate. Not recommended for v0.

**Recommended:** stop M3 until a `jwt_*` builtin lands upstream. M1
and M2 (interface skeleton + HMAC verification + payload normalization)
can ship without it. The connector's `call(method, args)` path can
require a manually-supplied installation token (string env var) as an
escape hatch for v0.

## What's unblocked

- `hmac_sha256(key, message) -> hex_string` — Harn builtin, just shipped.
- `constant_time_eq(a, b) -> bool` — **use this for `x-hub-signature-256`
  comparison**.
- HTTP, JSON, dict, list, regex, datetime stdlib.

## v0 milestones (build in order)

### M1 — Connector interface skeleton

- Stub all interface functions in `src/lib.harn`.
- `provider_id()` returns `"github"`. `kinds()` returns `["webhook"]`.
  `payload_schema()` returns the canonical schema dict.
- `init`, `activate`, `shutdown` manage module state in a top-level dict.
- Acceptance: `harn check src/lib.harn` exits 0; smoke test imports the
  module and calls each interface function without error.

### M2 — HMAC verification + event normalization

- Port HMAC verification from
  `/Users/ksinder/projects/harn/crates/harn-vm/src/connectors/github/mod.rs`.
  GitHub sends `x-hub-signature-256: sha256=<hex>`. Strip the
  `"sha256="` prefix, then `constant_time_eq` against
  `hmac_sha256(secret, raw.body_text)`.
- Reject (`Err`) on missing/mismatched signature, missing secret,
  unsupported event type.
- Normalize the verified payload per event type. v0 covers:
  `pull_request`, `push`, `issues`, `issue_comment`, `check_run`. Each
  produces the canonical envelope:
  ```harn
  {
    event_type: "pull_request.opened",
    resource_id: "<repo>/<number>",
    actor: { id, login, type },
    occurred_at: "...",
    repo: { owner, name, full_name },
    raw: <original payload>,
    // event-specific fields
  }
  ```
- Acceptance: `tests/normalize_smoke.harn` feeds 5+ recorded webhook
  payloads (one per event type, plus one tampered) through
  `normalize_inbound` and asserts outcomes.

### M3 — Outbound dispatch (with installation token escape hatch)

- `call(method, args)` dispatch table with at least:
  - `issues.create_comment`
  - `issues.update`
  - `pulls.create_review_comment`
  - `pulls.list_files`
  - `repos.get_content`
  - `check_runs.create`
  - `check_runs.update`
  - `graphql` — passes `{ query, variables }` to the GraphQL endpoint.
- For v0, accept the installation token as a string from
  `bindings.installation_token` (env var pass-through). Document the
  JWT-rotation gap loudly in the README.
- Honor `x-ratelimit-*` headers: if `x-ratelimit-remaining == 0`, sleep
  until `x-ratelimit-reset` (with a max sleep cap of 60s for v0; abort
  beyond that with a clear error).
- Acceptance: `tests/call_smoke.harn` exercises one REST call and one
  GraphQL call against a mocked endpoint and asserts the request shape
  and rate-limit handling.

### M4 — JWT-based token rotation (gated on upstream JWT builtin)

- When the upstream `jwt_*` builtin lands, implement
  `_mint_installation_token(app_id, installation_id, private_key)`:
  - Sign an ES256 JWT with iss=app_id, iat=now, exp=now+10min.
  - POST to
    `https://api.github.com/app/installations/<id>/access_tokens` with
    `Authorization: Bearer <jwt>`.
  - Cache the returned token + expiry in module state; refresh ~5 min
    before expiry.
- Acceptance: `tests/token_rotation_smoke.harn` (mocked) asserts
  refresh-on-expiry behavior.

## Recommended workflow

1. **Use a worktree per milestone:**
   ```sh
   cd /Users/ksinder/projects/harn-github-connector
   git worktree add ../harn-github-connector-wt-m1 -b m1-skeleton
   ```
2. **Read the Rust impl side-by-side** for HMAC + normalization details.
3. **File the JWT-builtin upstream ticket before M3.** Don't sit on it
   — it gates v1.0 even if v0 ships with the env-var escape hatch.
4. **Pin webhook fixtures from a sandbox app**, never from a production
   org. Strip user IDs and tokens from recordings.

## Reference materials

- Harn quickref: `/Users/ksinder/projects/harn/docs/llm/harn-quickref.md`.
- Harn language spec: `/Users/ksinder/projects/harn/spec/HARN_SPEC.md`.
- Existing Rust impl (the spec for behavior):
  `/Users/ksinder/projects/harn/crates/harn-vm/src/connectors/github/mod.rs`.
- HMAC builtins conformance fixture:
  `/Users/ksinder/projects/harn/conformance/tests/stdlib/hmac_sha256.harn`.
- GitHub webhook signature docs:
  <https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries>.
- GitHub App installation token docs:
  <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation>.
- GitHub REST API: <https://docs.github.com/en/rest>.
- GitHub GraphQL API: <https://docs.github.com/en/graphql>.

## Testing expectations

- Negative-path HMAC tests are mandatory (missing header, wrong
  secret, tampered body).
- Use `constant_time_eq` for *all* signature comparisons.
- Mock all live HTTP for v0 tests.
- Run before committing:
  ```sh
  cd /Users/ksinder/projects/harn
  cargo run --quiet --bin harn -- check /Users/ksinder/projects/harn-github-connector/src/lib.harn
  cargo run --quiet --bin harn -- lint  /Users/ksinder/projects/harn-github-connector/src/lib.harn
  cargo run --quiet --bin harn -- fmt --check /Users/ksinder/projects/harn-github-connector/src/lib.harn
  for t in /Users/ksinder/projects/harn-github-connector/tests/*.harn; do
    cargo run --quiet --bin harn -- run "$t" || exit 1
  done
  ```

## Definition of done for v0

- [ ] All interface functions implemented and `harn check` clean.
- [ ] HMAC verification uses `constant_time_eq`, with negative-path
      tests proving rejection of tampered payloads.
- [ ] `normalize_inbound` covers `pull_request`, `push`, `issues`,
      `issue_comment`, `check_run`.
- [ ] `call(method, args)` covers the methods listed in M3.
- [ ] Rate-limit handling honors `x-ratelimit-*` headers with a sane
      cap.
- [ ] JWT signing question filed as an upstream ticket on
      `burin-labs/harn` and referenced in CHANGELOG.
- [ ] **No v0.1.0 tag cut until [harn#345](https://github.com/burin-labs/harn/issues/345)
      and [harn#346](https://github.com/burin-labs/harn/issues/346)
      both land.** Token rotation gated on the JWT builtin landing
      separately.

## Future work (not v0)

- `github-sdk-harn` — a typed REST + GraphQL SDK (REST via
  `harn-openapi` against the published OpenAPI; GraphQL via codegen
  from the schema). Out of scope here. File when there's a real consumer.
