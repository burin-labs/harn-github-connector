<!--
Title this pull request `[Area] Sentence case description`.
Areas: Connector, Worktree, Release, Docs, CI, Tests.
Example: [Connector] Read private pull-request checks without widening App authority
-->

## Description

<!--
Three to five sentences in plain language: what changed, why, the one risk,
and how you verified it. Name any exported contract you changed, because that
is the part a consumer feels. Do not list files; the Files tab shows those.

Worked example:

  Reading checks on a private pull request fell back to the token path, which
  required repo-wide read authority the App does not have. This routes the
  read through the installation token and returns the documented typed error
  when the installation cannot see the repository. The risk is that a caller
  relying on the old fallback now gets a typed failure instead of a partial
  result, which is the intended behavior and is noted in CHANGELOG.md.
  Verified with a fixture that exercises both the visible and the invisible
  installation, plus the full package gate.

If this resolves an issue, say which sub-asks it closes:
`Closes #N items: 1, 3` or `Single-ask: #N`.
-->

## Test plan

<!--
What you actually ran and what happened. Name the check that would have failed
if this change were wrong, and say what remains unverified. A passing count is
inventory, not evidence.
-->
