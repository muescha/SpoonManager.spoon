# Local Changes & Forking — Decision Matrix

Focused prioritization for the "the user has modified an installed Spoon" cluster.

**Core insight:** this is a three-way diff — BASELINE (what was installed) vs.
LOCAL (on disk now) vs. UPSTREAM (newest). BASELINE→LOCAL is the user's edits,
BASELINE→UPSTREAM is the update. Everything hinges on establishing a baseline.

**Baseline sources, most to least reliable:**

1. Re-fetch pristine from a known source (the Adopt flow) — authoritative.
2. The user's own git history, if `~/.hammerspoon` is tracked — strong, opportunistic.
3. Reconstruct the upstream revision by install date + best content match — moderate.

Legend: **Effort** S/M/L · **Benefit** low/medium/high · **Foundation** = a base that unlocks the rest.

| # | Idea | Keyword | Description | Effort | Benefit | Verdict |
|---|------|---------|-------------|:------:|:-------:|---------|
| 17 | Backup + Fresh Diff | Safe & simple | Back up before every update, then diff against a fresh install. Pragmatic default — build first. | S | High | Yes · Foundation |
| 18 | Fingerprint | Baseline @ install | Store per-file hash + `sourceRevision` → "locally modified: yes/no". Base for the 3-way diff. | S | High | Yes · Foundation |
| 19 | Adopt Flow | Adopt existing | For manually installed Spoons: name the source → create a baseline + first diff. Solves the core problem. | M | High | Yes |
| 20 | 3-Way Diff | Edit vs. update | Separate baseline / local / upstream → "my change" vs. "update" vs. "conflict". | M | High | Yes |
| 21 | Change Protection | Skip on purpose | An update shows a diff instead of skipping blindly — the user decides, informed. | S | Medium | Yes |
| 22 | User Git History | Config in git | If `~/.hammerspoon` is git-tracked: use the existing history as a strong baseline. | M | Medium | Optional |
| 23 | History Reconstruction | State at date | Find the upstream revision by install date + best content match. Robust, but a stretch goal. | L | Medium | Later |
| 24 | Git Backing | git under the hood | Spoon as a git repo, pristine as the first commit → diff/merge/conflicts for free. Heavier — weigh it. | L | Medium | Later |
| 25 | Fork Helper | Own Spoon | Edits as commits, repoint source to a fork. Rename `Tool→MyTool` best-effort only + generate push command. | M | Medium | Later |

## Dropped / Out of Scope

| # | Idea | Keyword | Why not | Verdict |
|---|------|---------|---------|---------|
| 26 | Auto GitHub Push | auto repo + push | Pulls token/auth management and outward actions in. Instead: generate the ready command, the user pushes themselves. | No |
| 27 | Blind Detect | no baseline & source | Detect changes with no comparison point — logically impossible. Always solve via Adopt (19). | No |

## First Wave

Build 17 and 18 first (the foundation: backup safety + fingerprint baseline),
then the separation core 19–21. Items 22–25 are the next stage; 26–27 are out of
scope.
