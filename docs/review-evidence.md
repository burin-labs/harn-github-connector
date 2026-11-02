# Review receipt reference

Import the pure reader and writer from `harn-github-connector/review_evidence`.
Neither function reads GitHub, credentials or local files.

`stamp_github_review_author_evidence(body, source, replies = [], marker_prefix = "<!-- automated-review-author-evidence: ")`
returns `Result<string, string>` containing the body with a final receipt line.
Supply the frozen source head actually reviewed, not a commit copied from a
later GitHub review observation. Replies identify the structured author replies
consumed by that review; an empty list declares that none were consumed through
that protocol. The writer sorts replies by fingerprint.

`read_github_review_author_evidence(body, source, marker_prefix = "")`
returns `Result<GithubReviewAuthorEvidenceReceipt, string>`. The independently
supplied repository, pull request and head must match the receipt. An explicit
marker prefix restricts the accepted producer namespace; an empty prefix
accepts any syntactically valid reviewer namespace. Only the final nonblank
line supplies evidence.

`source` is a `GithubReviewSourceIdentity` record with named `repository`, `pr`
and `head_sha` fields, keeping the repository name and reviewed head distinct.

| Field | Meaning |
| --- | --- |
| `schema` | Exactly `review.author_evidence.v1` |
| `repository_digest` | SHA-256 of the exact `owner/repository` string |
| `pr` | Pull-request number |
| `head_sha` | Source head the reviewer actually read |
| `replies[].fingerprint` | Unique 16-character lowercase hexadecimal reply identity |
| `replies[].digest` | 64-character lowercase hexadecimal digest of the consumed reply |

Missing or malformed receipts, mismatched source identity and invalid or
duplicate reply identities return an error. Unknown evidence never becomes a
matching approval. The caller still owns actor trust, required checks and the
repository's protected-review policy; a receipt does not grant merge authority.

```harn
import {
  read_github_review_author_evidence,
  stamp_github_review_author_evidence,
} from "harn-github-connector/review_evidence"

fn main() {
  const source = {repository: "octo-org/octo-repo", pr: 42, head_sha: "a" * 40}
  const stamped = stamp_github_review_author_evidence("Approved.", source)
  assert(is_ok(stamped))
  const bound = read_github_review_author_evidence(unwrap(stamped), source)
  assert(is_ok(bound))
}
```
