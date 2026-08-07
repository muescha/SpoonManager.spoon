# Ideas Roadmap

An overview of every idea gathered for SpoonManager, numbered, with an effort and
benefit estimate and a verdict on whether it is worth building. It summarizes the
planned notes under `../planned/`; nothing here is implemented yet.

Legend:

- **Effort** — S small, M medium, L large.
- **Benefit** — low, medium, high.
- **Foundation** — a base that unlocks other work.
- **Verdict** — Yes (build), Later, Optional, No (out of scope).

## A. Structure and Hosting

See `../planned/repository-structure-and-hosting.md`.

| # | Idea | Keyword | Description | Effort | Benefit | Verdict |
|---|------|---------|-------------|:------:|:-------:|---------|
| 01 | Repo Split | Two Repos | Tool (`spoonmanager`) and community catalog (`spoonify`) kept separate — PR streams never collide. | S | High | Yes · Foundation |
| 02 | Structure Rework | Monorepo | `Source/SpoonManager.spoon`, `Spoons/*.zip`, release ZIP for bootstrap. Mirrors Hammerspoon/Spoons. | M | Medium | Yes · Foundation |
| 03 | Root Manifest | Auto-Discovery | `spoonify.json` at the repo root as a fixed location — like `package.json`. | S | Medium | Yes · Foundation |
| 04 | Pages Hosting | GitHub Pages | Deploy `website/` via Actions — free, no domain needed. | S | Medium | Yes · Foundation |
| 05 | Custom Domain | .de domain | ~EUR 3.71/year, CNAME to Pages. Nice, but not needed — addable anytime. | S | Low | Optional |

## B. Discovery and Distribution

See `../planned/discovery-website-and-gui.md`.

| # | Idea | Keyword | Description | Effort | Benefit | Verdict |
|---|------|---------|-------------|:------:|:-------:|---------|
| 06 | Catalog Repo | spoonify index | Central index of many manifests, curated via pull requests. | M | High | Yes |
| 07 | Schema Validation | CI gate | JSON schema + Action checks every PR: valid, allowed sources only, no local paths. | M | High | Yes |
| 08 | Search Website | brew.sh style | Static page + JSON feed, client-side search (Fuse.js). No backend, no running cost. | M | High | Yes |
| 09 | Copy Snippets | JSON / Lua | Copy config JSON or builder Lua per result — generated from the schema (no drift). | S | High | Yes |
| 10 | One-Click Import | hammerspoon:// | URL scheme via `hs.urlevent` → one-click install. Confirmation dialog mandatory (RCE risk). | M | High | Yes |
| 11 | In-App GUI | chooser / webview | Search and install right inside Hammerspoon. Richer, but a bigger piece of work. | L | Medium | Later |
| 12 | Webview Reuse | Page = GUI | Load the hosted website in `hs.webview` → don't build the UI twice. Install via URL scheme. | S | Medium | Yes |
| 13 | No-init.lua Install | GUI without code | Load installed Spoons from the registry on startup — the user never touches `init.lua`. | M | High | Yes |

## C. State and Registry

See `../planned/registry-history-status.md`.

| # | Idea | Keyword | Description | Effort | Benefit | Verdict |
|---|------|---------|-------------|:------:|:-------:|---------|
| 14 | Installed Registry | What's installed | Persistent "last successful state" — the base for diff, GUI, status and no-init.lua. | M | High | Yes · Foundation |
| 15 | History Log | Attempts | Log attempts/failures separately from installed state — for a timeline and troubleshooting. | M | Medium | Later |
| 16 | Status View | Status object | Derived view (installed / loaded / localChanges / updateAvailable) — a view, not the source of truth. | S | Medium | Later |

## D. Local Changes and Forking

See `../planned/local-changes-and-forking.md`. A focused decision matrix for this
cluster is also kept as a standalone deliverable (Markdown and HTML, English and
German).

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

## Summary

Active ideas: 25 — 17 Yes, 6 Later, 2 Optional. Dropped: 2.

Recommended first wave: the Foundation ideas (01–04, 14, 17, 18) unlock almost
everything else. Then the discovery core (06–10) and the local-changes core
(19–21).
