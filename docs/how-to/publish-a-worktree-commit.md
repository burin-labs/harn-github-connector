# Publish a worktree as a GitHub-signed commit

Follow these steps when CI must publish an exact local Git state without
managing Git objects.

## 1. Call the worktree adapter

The `harn-github-connector/worktree` export reads one local Git state and
creates a GitHub-signed commit. It is the only export that runs `git` commands.
The default export uses HTTP only.

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
}
const receipt = unwrap(github_commit_worktree(harness, request, {installation_token: token}))
```

| Helper | Purpose |
| --- | --- |
| `github_worktree_delta(process, selector)` | Derive typed additions/deletions from an exact Git state. No network I/O. |
| `github_commit_worktree(harness, request, options)` | Derive, take the branch lease, publish through `github_create_signed_commit`, return one receipt. |

## Check supported Git states

- `source` is `"worktree"` (HEAD versus the full working tree, including
  untracked non-ignored files, staged through a scratch `GIT_INDEX_FILE`) or
  `"index"` (HEAD versus the caller's real index). Neither mutates the caller's
  index or working tree.
- `base_oid` must equal the local `HEAD`; it defaults to it. A payload derived
  against a different tree would not describe the leased commit.
- Renames become delete-old plus add-new. Blob bytes are preserved exactly,
  binary included.
- `createCommitOnBranch` carries only `path` and `contents`. It preserves the
  base tree mode for a tracked path. The adapter rejects unsupported modes
  before making a network request:

  | Case | Outcome |
  | --- | --- |
  | Tracked `100755` edited, mode unchanged | Published; GitHub keeps `100755` |
  | New path with mode `100755` (added, copied, or a rename destination) | `unsupported_new_executable` |
  | Mode changes between the base tree and the selected state | `unsupported_mode_change` |
  | Symlink `120000` or submodule `160000` on either side | `unsupported_file_mode` |

  Deletions carry no mode and are always supported.
- An empty delta returns `committed: false`, `branch_action: "skipped"`, and
  performs no network call.
- A branch head that differs from the lease fails with `stale_head` unless
  `reset_branch` is set.

## 2. Run the command from CI

`harn-github-connector/publish` is the command-line entry point. Harn packages
export modules, so add one entry file for `harn run`:

```harn,ignore
import { publish_main } from "harn-github-connector/publish"

fn main(harness: Harness) {
  harness.runtime.exit(publish_main(harness, argv ?? []))
}
```

```sh
harn run --no-sandbox scripts/signed-commit/publish.harn -- \
  --repo octo-org/octo-repo \
  --branch automation/bump \
  --headline "Bump the pinned runtime" \
  --source index
```

`--no-sandbox` is required: the adapter runs low-level `git` commands, writes a
scratch index outside the checkout, and calls the GitHub API.

| Flag | Meaning |
| --- | --- |
| `--repo` | Target repository as `owner/repo`. Required. |
| `--branch` | Automation branch to create or reset onto the base commit. Required. |
| `--headline` | Commit headline. Required. |
| `--body` | Optional commit body. An absent body stays absent, not empty. |
| `--repo-dir` | Checkout to read from. Defaults to the current directory. |
| `--source` | `worktree` (default) or `index`. |
| `--no-reset` | Fail instead of force-moving a branch that is not at the base commit. |

Exit status is `0` for published, `1` for publish failure, and `2` for invalid
arguments. An empty delta exits `1` rather than reporting success for a commit
that was never made; callers that stage their own change have already
established there is something to publish.

Set `GITHUB_INSTALLATION_TOKEN`, or set `GITHUB_APP_ID` and
`GITHUB_INSTALLATION_ID` with a private key. See
[Configure a GitHub App](configure-github-app.md).
