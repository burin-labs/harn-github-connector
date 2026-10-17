# Publish a GitHub-signed commit

Use the `worktree` export to publish one exact local Git state through GitHub's
`createCommitOnBranch` mutation. The default connector export stays HTTP-only;
this adapter is the package's only Git subprocess boundary.

## Publish from Harn

Pass authentication inside the typed request:

```harn,ignore
import {
  GithubWorktreeCommitRequest,
  github_commit_worktree,
} from "harn-github-connector/worktree"

const request: GithubWorktreeCommitRequest = {
  owner: "octo-org",
  repo: "octo-repo",
  branch: "automation/bump",
  headline: "Bump the pinned runtime",
  repo_dir: "/path/to/checkout",
  source: "worktree",
  create_branch: true,
  reset_branch: true,
  options: {installation_token: env("GITHUB_INSTALLATION_TOKEN")},
}
const receipt = unwrap(github_commit_worktree(harness, request))
```

Choose `source: "worktree"` to compare `HEAD` with tracked, staged, modified,
and untracked non-ignored files. The adapter uses a scratch Git index and does
not change the caller's index or working tree.

Choose `source: "index"` to publish only the caller's staged state.

## Preserve the lease

`base_oid` must equal the local `HEAD`; it defaults to that value. The remote
branch must also match the lease unless `reset_branch` is true. A mismatch
returns `stale_head` before content is published.

An empty delta returns `committed: false` and
`branch_action: "skipped"`, and performs no network call.

## Recheck publication authority

Set `request.options.authorize_mutation` to a `GithubMutationAuthorization`
callback, `fn() -> Result<bool, GithubConnectorError>`. Read current authority
inside that callback. The shared HTTP owner calls it after preparation and
budget admission, immediately before each unsafe request. This includes POST
GraphQL queries; GET, HEAD and OPTIONS do not consult mutation authority.

Return `Ok(true)` only when the current operation is authorized. `Ok(false)`
returns `authorization_denied`; an `Err` is preserved, and a thrown read returns
`authorization_unmeasured`. Each refusal withholds the next mutation. Cleanup
of a staging branch created by this operation still runs. An empty delta never
calls the callback.

Guarded writes use one HTTP attempt. Authentication and rate-limit retries at
the client owner pass through the callback again. Without the option, existing
retry policy is unchanged.

The authority read and GitHub mutation are separate operations. Authority can
change after the last read; this callback does not make an external control
atomic with publication. The worktree adapter uses the existing atomic ref
transaction for target movement, so a changed branch fails the expected-object
lease even if it moves during authorization. An early observed mismatch remains
`stale_head`; final atomic refusals are `ref_update_refused`, while uncertain
outcomes are `ref_update_unknown` and require reconciliation. Signature checks
still apply.

## Check supported Git modes

GitHub's mutation accepts paths and content, not arbitrary Git modes. The
adapter rejects unsupported modes before any network request.

- Editing a tracked `100755` file without changing its mode is supported.
  GitHub preserves `100755`.
- Adding, copying, or renaming to a new `100755` path returns
  `unsupported_new_executable`.
- Changing a tracked path's mode returns `unsupported_mode_change`.
- Adding or editing a symlink (`120000`) or submodule (`160000`) returns
  `unsupported_file_mode`.
- Deleting a path is supported.

Renames become one deletion and one addition. Binary bytes are preserved.

## Publish from CI

Create a small entry file for the `publish` export:

```harn,ignore
import { publish_main } from "harn-github-connector/publish"

fn main(harness: Harness) {
  harness.runtime.exit(publish_main(harness, argv ?? []))
}
```

Then invoke it from the checkout:

```sh
harn run --no-sandbox scripts/signed-commit/publish.harn -- \
  --repo octo-org/octo-repo \
  --branch automation/bump \
  --headline "Bump the pinned runtime" \
  --source index
```

The adapter needs `--no-sandbox` because it runs Git plumbing, creates a
scratch index outside the checkout, and calls GitHub.

Exit status `0` means a commit was published, `1` means publishing failed or
the delta was empty, and `2` means the command arguments were invalid.

## Inspect after a lost response

Read a known commit object before deciding whether to resume publication:

```harn,ignore
import { github_read_signed_commit } from "harn-github-connector/default"

const observed = github_read_signed_commit(harness, {
  owner: "octo-org",
  repo: "octo-repo",
  oid: expected_commit,
})
```

The receipt contains the exact commit, tree and complete parent list, plus the
same valid GitHub-generated signature evidence required by creation. Compare
the tree and parents with your frozen candidate before accepting it. This read
never creates a commit or moves a ref. Missing objects, malformed identities,
incomplete or more than 20 parents, and other signature states return a refusal;
they do not authorize another write. A measured root commit has an empty parent
list, while absent parent evidence is refused.
