# Local Changes and Forking

This note records the idea of helping users who have modified an installed
Spoon: detecting local changes, showing a diff on update, and turning local
edits into an owned fork. It builds on the fingerprints and status already
sketched in `registry-history-status.md`.

Existing primitives this relies on:

- `fingerprints.localHash` and `fingerprints.sourceRevision` in the installed
  record.
- the `localChanges` field in the status object.
- the README principle "protect existing local changes by default".

The goal is to make those primitives visible and actionable.

## Core Insight: This Is a Three-Way Diff

What the user wants is what a version control system already does. There are
three states:

```text
BASELINE (what was installed)  ──►  LOCAL (what is on disk now)   = the user's local edits
        │
        └───────────────────────►  UPSTREAM (newest version)     = the update
```

- BASELINE to LOCAL = "what did I change"
- BASELINE to UPSTREAM = "what is an update"
- both changed at the same place = a conflict

Everything depends on the BASELINE. Without a baseline there is no diff. The hard
part of this feature is therefore establishing a baseline, especially for Spoons
that were installed manually.

## Establishing a Baseline

Baseline sources, ranked by reliability:

1. **Re-fetch the pristine source (authoritative).** When the source repository
   and revision are known, download the pristine version and compare by content
   hash. This is exact. It is the basis of the "adopt" flow below.
2. **The user's own git history (strong, opportunistic).** Many users track
   `~/.hammerspoon` in git. If the Spoon path is inside a git work tree, `git
   log` and `git blame` give real history: when files were added and what
   changed since. Detect this by checking for an enclosing work tree and offer
   to use it. Only available when the user tracks their config, but reliable
   when present.
3. **Reconstruct the upstream baseline from source history (moderate).** Even
   without a stored baseline, the source history can be replayed to the estimated
   install date. GitHub can resolve the commit that was current at or before a
   date (the commits API with an `until` parameter) and serve the tree or ZIP at
   that revision. Comparing local against that point-in-time state distinguishes
   "unmodified copy from then" from "modified".

   The estimated date comes from file and folder modification times
   (`hs.fs.attributes`): a cluster of files sharing one timestamp suggests the
   install date, and newer files suggest later edits.

   The refinement that makes this robust: do not trust the date alone. Search a
   bounded window of the history and pick the revision whose content best matches
   the local files. The best content match is most likely the actual install
   point, and the remaining differences are the local edits. The date becomes a
   seed for the search, not the answer.

   Limits: this fails when the history was force-pushed or rewritten, or when the
   Spoon came from a ZIP that corresponds to no commit; a date-to-commit guess
   misses when the install came from a release or tag; and "local edit" versus
   "wrong revision" stays a best guess. Modification times are only a hint,
   because unzipping, `git checkout`, and copying often reset them all to a
   single moment.

## Backup and Diff Against a Fresh Install

The pragmatic default sidesteps baseline archaeology entirely: back up the
current folder, then install fresh, then diff.

- **Always back up before a reinstall or update.** Copy the current (possibly
  modified) folder aside first, then install. The user can never lose their
  modified version, and this is what makes "protect local changes" real. Trivial
  to implement, and it should run on almost every update.
- **Diff local against a fresh install.** This manufactures the comparison point
  by installing cleanly, instead of reconstructing a historical baseline. It is
  concrete and excellent for troubleshooting ("is this broken because of my edit
  or because of an update?").

The honest limit is which version is installed fresh:

- Fresh install of the **latest** version produces a two-way diff that mixes the
  user's edits and upstream updates; they cannot be separated.
- Fresh install of the **same version originally installed** yields a clean
  "just my edits" diff, but that requires knowing the revision, which is where
  baseline sources 1 and 3 come back in.

So backup-plus-fresh-diff is the robust, simple default; baseline reconstruction
is the upgrade for separating edits from updates (the full three-way view). They
complement each other and do not replace each other. The backup also produces the
baseline for next time.

## Feasible and Valuable

**1. Fingerprint baseline on install (already planned).** Record per-file hashes
and `sourceRevision` at install time. Re-hash later to answer "locally modified:
yes or no". Cheap, high value, the foundation for everything else.

**2. An "adopt" flow for manually installed Spoons.** This solves the core
problem. The user names the source repository; SpoonManager fetches the pristine
version, diffs it against the local files to show "this is what you changed", and
records a baseline from then on. It converts the unsolvable "I don't know the
original state" into a single deliberate step.

**3. Diff display on update.** With baseline, local, and upstream available, a
textual three-way diff is standard. "Update only" versus "your change only"
versus "conflict" falls out automatically. Show it in the GUI or webview, or
write it to a file.

**4. Informed protection of local changes.** Instead of silently skipping on
update (the current default), the diff shows *why* it is skipped so the user
decides consciously.

## Feasible with Caveats

**5. Git under the hood instead of a custom implementation.** Initialize the
Spoon folder as a git repository at install and commit the pristine version as
the first commit. Then "local changes" is `git diff`, an update is fetch plus
merge, and conflicts come from git rather than custom code. Trade-off: a `.git`
folder in every Spoon, git as a dependency, and Spoons installed from release
ZIPs have no git so the baseline commit must be created explicitly. Decide
between git-based (powerful, heavier) and hash-plus-stored-copy (lighter, but
diff and merge are hand-built).

**6. Turning a Spoon into an owned fork (`Tool.spoon` to `MueschaTool.spoon`).**
The valuable core is feasible: capture the local edits as git commits, create an
owned repository, and repoint SpoonManager's source to that fork so it tracks
cleanly afterward. However, the rename itself is fragile: the internal name
appears in several places (`obj.name = "Tool"`, the folder name,
`hs.loadSpoon("Tool")`, metadata), and Spoons do not follow a strict enough
convention to rewrite all references safely. Realistic scope: a best-effort
rename plus a report of what was changed and what to check, not a guaranteed
magic rename.

## Pointless or Out of Scope

**7. Fully automatic GitHub repository creation and push.** Technically possible
via the `gh` CLI or the GitHub API, but it pulls SpoonManager into credential
and token management and outward-facing actions: a lot of complexity and
security surface for little core value. Better: SpoonManager does the local part
(git init, commits, prepare the remote) and hands the user the ready `git` or
`gh` command to run themselves. The user keeps control and there is no auth
burden.

**8. Auto-detecting local changes with no baseline and no known source.** Not
possible; there is nothing to diff against. Do not promise it. Always route
through the adopt step instead.

## Two Faces of One Feature

Local-change detection (a) and forking (b) are one feature, not two. Once a Spoon
has a baseline and is git-tracked, "make it my fork" is just "commit my changes
and point the source at my repository".

## MVP Slice

A sensible first cut covers most of the real pain:

```text
1. backup before every reinstall or update
2. fingerprint baseline on install
3. adopt flow for existing installs
4. diff on update (backup-vs-fresh as the simple default)
5. informed protection of local changes
```

Items 5 and 6 (git under the hood, fork and rename) are the next stage. Item 7
is left out; only the command is generated.

## Status

Future implementation work. Depends on the installed registry and fingerprints
from `registry-history-status.md`, and pairs well with the GUI and URL-scheme
surfaces in `discovery-website-and-gui.md`.
