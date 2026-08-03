# Set up a GitHub App

This guide connects one GitHub App installation to Harn. Use a GitHub App for
webhooks and repository automation. Use the separate user OAuth helpers only
when a person must connect their own GitHub account.

## Create and install the app

In GitHub, create an app, set its webhook URL to
`https://<public-host>/webhooks/github`, and install it on the repositories the
workflow may access.

Record these non-secret identifiers:

- App ID
- Installation ID

Download one private key and create a webhook secret. Keep both out of source
control and shell history. GitHub documents the full flow in
[Registering a GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app).

## Store and verify the credentials

Pass secret files to Harn without copying their values into the command:

```sh
harn connect github --app-slug harn-example --app-id 12345 \
  --private-key-file ./harn-example.private-key.pem \
  --webhook-secret-file ./github-webhook-secret --json
harn connect status --connector github --json
```

Remove the temporary files after the status command reports a healthy
connection. The connector resolves the private key through Harn's secret
provider; production code should pass `private_key_secret`, not
`private_key_pem`.

An outbound request may instead carry an existing installation token:

```harn
const options = {
  installation_token: env("GITHUB_INSTALLATION_TOKEN"),
}
```

For local development, `allow_gh_auth_fallback: true` permits an explicit
`gh_token`, `GH_TOKEN`, `GITHUB_TOKEN`, or `gh auth token`. Do not enable that
fallback in unattended production workflows because it changes the acting
identity.

## Grant the narrow permissions

GitHub App permissions are independent. Grant only the rows used by the
workflow.

- Pull-request reads, diffs, files, and reviews need Pull requests: read.
- Pull-request edits, merges, auto-merge, and review comments need Pull
  requests: write.
- Repository files and releases need Contents: read.
- File writes and signed commits need Contents: write.
- Branch-protection reads need Administration: read.
- Workflow dispatch needs Actions: write.
- Workflow runs and logs need Actions: read.
- Repository runner reads need Administration: read.
- Repository runner writes need Administration: write.
- Organization runner reads need Organization self-hosted runners: read.
- Organization runner writes need Organization self-hosted runners: write.
- Check-run writes need Checks: write.
- Issue reads and writes need the matching Issues permission.

Protected branches and organization rulesets may also require a bypass actor,
administrator permission, a merge queue, signed commits, reviews, or named
checks. The connector reads and enforces observed repository policy where the
operation supports it; GitHub remains authoritative. See
[About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).

## Verify webhooks

GitHub deliveries must include `X-GitHub-Event`, `X-GitHub-Delivery`, and
`X-Hub-Signature-256`. The connector verifies the signature over the raw body
before parsing the event.

Managed ingress hosts may provide the secret as `signing_secret`, or refer to a
secret-provider entry through `signing_secret_id`,
`secret_ids.signing_secret`, or `config.secrets.signing_secret`.

Use GitHub's delivery view to redeliver a synthetic test event. Confirm that a
valid signature produces one event and a modified signature produces none.
The promoted payload fields are listed in the
[webhook event reference](events.md).

## Rotate credentials

Add and validate a replacement App key before deleting the old key in GitHub.
For a webhook-secret rotation, update GitHub and the Harn secret provider in
the same maintenance window. Prove the new signature succeeds and the old
signature fails before closing the change.
