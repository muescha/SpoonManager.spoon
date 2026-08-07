# Repository Structure and Hosting

This note records the planned repository layout, hosting, and distribution
model for SpoonManager. It fixes decisions that were made before
implementation so the later restructure follows a known target.

## Two Repositories

The project should be split into two repositories with clearly separated
purposes. This keeps pull requests from mixing and keeps the tool code separate
from externally contributed catalog data.

| Repository | Purpose | What a pull request means |
|------------|---------|---------------------------|
| `spoonmanager` | The tool (code) plus its own `spoonify.json` | A code contribution to the manager |
| `spoonify` | The community catalog / index | "I want to list my Spoon" |

Naming stays consistent between the format and the index:

- `spoonify.json` is the *file / format*. It lives in the root of every Spoon
  repository for auto-discovery.
- `spoonify` is the *repository* that bundles many of these manifests into one
  index.

## Ownership

The tool and the community catalog should stay under the `muescha` account, not
under a product brand. The catalog lives on pull requests from outside
contributors, so a neutral, open-source home is more inviting and avoids the
licensing and ownership questions that arise when outside contributions land in
a repository intended for later commercialization.

## The `spoonmanager` Repository

The repository is renamed from `SpoonManager.spoon` to `spoonmanager`. The Spoon
itself moves into `Source/SpoonManager.spoon`, mirroring the layout of the
official `Hammerspoon/Spoons` repository. This also makes the repository the
first real example of its own `spoonify.json` format (dogfooding).

```
spoonmanager/                          -> muescha.github.io/spoonmanager/
├── Source/
│   └── SpoonManager.spoon/            <- the Spoon (init.lua, lib/, tests/)
├── Spoons/
│   └── SpoonManager.spoon.zip         <- release artifact (bootstrap)
├── spoonify.json                      <- own manifest at root (auto-discovery)
├── docs/
│   └── architecture/
├── website/                           <- GitHub Pages content
├── .github/workflows/pages.yml        <- deploys website/ to Pages
└── README.md
```

### Manifest at the Root

`spoonify.json` lives in the repository root, following the same convention as
`package.json`. A tool can then attempt `/(root)/spoonify.json` on any Spoon
repository without extra configuration.

Discovery rule: **a Spoon repository publishes its manifest as `/spoonify.json`
in the repository root.**

Raw URL:

```
raw.githubusercontent.com/muescha/spoonmanager/main/spoonify.json
```

### Bootstrap

SpoonManager cannot install itself (chicken-and-egg). Because the Spoon now
lives in a nested folder, the repository should publish a release
`SpoonManager.spoon.zip`. A user downloads and extracts it into
`~/.hammerspoon/Spoons/`, which is even simpler than cloning a nested folder.

## Hosting with GitHub Pages

The human-facing site is served with GitHub Pages. No domain purchase is
required to start; the project-site URL is derived from the repository name.

- Machine endpoint (the manifest JSON): served directly from
  `raw.githubusercontent.com`, which is already listed as trusted in
  `spoonify-manifests.md`.
- Human endpoint (landing page / docs): GitHub Pages at
  `muescha.github.io/spoonmanager/`.

GitHub Pages "deploy from a branch" only serves from `/(root)` or `/docs`.
Because `/docs` already holds the architecture documentation, the website lives
in `website/` and is deployed by a small GitHub Actions workflow
(`.github/workflows/pages.yml`) so an arbitrary folder can be used without
disturbing `docs/`.

### Optional Custom Domain

A custom domain is optional and deferred. If the project gains traction,
a `.de` domain (roughly 3.71 EUR per year; the displayed ~1 EUR is only the
first-registration price) can be pointed at GitHub Pages with a `CNAME` for no
additional hosting cost. Country and developer TLDs such as `.dev` or `.app`
remain a later option and are not needed to start.

## The `spoonify` Repository

The community catalog is a separate repository, created when the catalog work
begins. Keeping it separate means catalog pull requests never collide with tool
pull requests, and outside contributions stay out of the tool's code base.

```
spoonify/                              -> muescha.github.io/spoonify/
├── index.json                         <- list of manifest URLs
├── manifests/                         <- external manifests for repos without their own
│   └── *.json
├── schema/
│   └── spoonify.schema.json           <- JSON schema for validation
├── .github/workflows/validate.yml     <- validates each PR against the schema
├── website/                           <- optional browse / search UI
└── README.md                          <- contribution guide: "how to list your Spoon"
```

### Contribution Flow

1. A contributor adds their Spoon by editing the catalog JSON in a pull request,
   using provider-based sources only (`type: github` and friends), never local
   paths. This matches the "Source Safety" section of `spoonify-manifests.md`.
2. Continuous integration validates each pull request: valid JSON, checked
   against the JSON schema (only allowed `source.type` values, no resolved
   fields such as `sourceKind` or `command.*`).
3. The maintainer reviews and merges. The merged file is immediately available
   through `raw.githubusercontent.com`.

This provides curated intake with a review gate and no server, no domain, and no
running cost.

## Relationship to Other Notes

- `spoonify-manifests.md` defines the manifest format itself. This note only
  records where the files live and how they are hosted.
- Manifest loading (`from.spoonify(...)`, `from.spoonifyIndex(...)`) remains
  future implementation work as described in that note.
