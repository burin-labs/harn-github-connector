# Configure a GitHub App

Follow these steps to authenticate outbound calls and verify inbound webhooks.

## 1. Register and install the App

Create a [GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)
and install it into the target account or repository set.
Set its webhook URL to `https://<public-host>/webhooks/github`, record the App
ID and Installation ID, configure a webhook secret, then store the private key
PEM in a Harn SecretProvider. Do not commit real GitHub App private keys or
webhook secrets.

## 2. Store the credentials

```sh
harn connect github --app-slug harn-example --app-id 12345 \
  --private-key-file ./harn-example.private-key.pem \
  --webhook-secret-file ./github-webhook-secret --json
```

The command copies the credentials into the configured Harn secret provider.
Remove the input files after the next step passes.

## 3. Verify the connection

```sh
harn connect status --connector github --json
```

The result must report the connector and both required secrets as healthy.

Inbound webhooks must include GitHub's `X-GitHub-Event`,
`X-GitHub-Delivery`, and `X-Hub-Signature-256` headers. The connector verifies
the signature against the raw request body with `signing_secret`.

Ingress hosts can pass the webhook secret by value as `signing_secret`
or by secret-provider alias through `signing_secret_id`,
`secret_ids.signing_secret`, or `config.secrets.signing_secret`.

## 4. Make a test call

```harn
import { call } from "harn-github-connector/default"

fn main(harness: Harness) {
  unwrap(call(harness, "github.issue.comment", {
    app_id: harness.env.get("GITHUB_APP_ID"),
    installation_id: harness.env.get("GITHUB_INSTALLATION_ID"),
    private_key_secret: "github/app-private-key",
    owner: "octo-org",
    repo: "demo",
    issue_number: 123,
    body: "Thanks for the pull request.",
  }))
}
```

For local fixture tests only, `private_key_pem` can be passed inline.
Use `private_key_secret` outside tests so Harn reads the PEM from the host's
secret provider.

## 5. Grant the required permissions

Grant only the permissions used by your methods. GitHub maintains the
[permission map for GitHub App REST endpoints](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps).

| Methods | GitHub App permission |
| --- | --- |
| Issue helpers and issue comments | Issues read/write, or Pull requests read/write when acting on PRs. |
| PR read helpers, diffs, files, and reviews | Pull requests read. |
| PR merge, safe merge, auto-merge, and review comments | Pull requests write. Protected branches can require administrator or bypass permissions. |
| Repository content and release helpers | Contents read. |
| Repository content write helpers and `git.create_commit` | Contents write. Pass `github_author_choice` from `std/disclosure` to enforce `author_mode`. |
| `git.delete_ref` | Contents write. |
| Branch protection helpers | Administration read. |
| Actions dispatch | Actions write. |
| Actions run and log reads | Actions read. |
| Self-hosted runner reads (list/get/labels.list/downloads) | Repo `administration:read` or org `organization_self_hosted_runners:read`. |
| Self-hosted runner writes (registration/remove tokens, JIT config, delete, label add/replace/remove, runner groups) | Repo `administration:write` or org `organization_self_hosted_runners:write`. |
| Check run create/update | Checks read/write. |
| `api_call` and `graphql` | Whatever the endpoint, query, or mutation requires. |

## Use local GitHub CLI authentication

Callers that already have an installation token can pass `installation_token`.
For local development, pass `allow_gh_auth_fallback: true`.
When enabled and no installation credentials are present, the connector uses an
explicit `gh_token`, `GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth token`.

## Rotate credentials

Add and validate a replacement App key before deleting the old key in GitHub.
For a webhook secret, update GitHub and the Harn secret provider in one
maintenance window. Prove the old signature is rejected and the new signature
is accepted.

See [Runtime policy](../reference/runtime-policy.md) for token caching, retries,
rate limits, and error categories.
