# Atomically update Git refs

Use `github_update_refs` when a branch update must check another ref in the same
repository. Every member supplies its exact `before_oid`. GitHub applies all
members atomically or refuses the transaction.

```harn
import { github_update_refs } from "harn-github-connector/default"

const result = github_update_refs(harness, {
  owner: "octo-org",
  repo: "octo-repo",
  updates: [
    {ref: "refs/heads/main", before_oid: previous_commit, after_oid: integrated_commit},
    {ref: "refs/heads/ship-control", before_oid: controller_commit, after_oid: controller_commit},
  ],
  options: {installation_token: token, allow_gh_auth_fallback: false},
})
```

The unchanged control ref is a guard. A stale control object prevents the main
update too. Supply fully qualified, unique refs, with at most 32 members. Force
defaults to false. Forty zeroes as `before_oid` require absence; forty zeroes as
`after_oid` delete an existing ref under its exact expected object.

A successful receipt acknowledges the whole transaction and retains its
before/after objects. It does not claim those refs stayed unchanged afterward.
The transaction identifier correlates the acknowledgement; it is not a provider
idempotency key.

On an error, inspect `mutation_outcome`. `refused` means no mutation was
dispatched or the provider explicitly refused it. `unknown` requires observation
and reconciliation before another effect. A timeout, malformed acknowledgement,
server error or untyped GraphQL error remains unknown. Do not infer success or
safe replay from an error message. The connector disables unsafe transport
retries even when caller options request them.

`github_release_ref` uses this same transaction owner for deletion. Its initial
read reports an already absent ref or another holder; the mutation checks the
expected object again. A replacement between those operations survives.

The installation must authorize GitHub API network mutations and supply a
credential with permission to update the selected refs. Importing this package
does not grant either capability. The operation respects GitHub protection
rules; it does not create a bypass.

[API reference](api.md). [GitHub transaction contract](https://docs.github.com/en/graphql/reference/git#updaterefs).
