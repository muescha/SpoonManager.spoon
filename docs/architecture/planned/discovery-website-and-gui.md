# Discovery Website and GUI

This note records the planned discovery experience for SpoonManager: a static
search website, one-click import through a URL scheme, and a future in-app GUI.
It builds on the catalog described in `repository-structure-and-hosting.md` and
the manifest format in `spoonify-manifests.md`.

## One JSON Source, Multiple Consumers

The `spoonify` index is the single source of truth. The same JSON feed serves
every surface, the same way Homebrew's `formulae.brew.sh/api` serves both the
website and the `brew` CLI.

```text
spoonify index.json  ─┬─►  Website (search + copy JSON/Lua + one-click)
                      ├─►  SpoonManager builder (Lua)
                      └─►  future GUI (hs.chooser / hs.webview)
```

## Discovery Website

The website is a static site on GitHub Pages (`muescha.github.io/spoonify/`),
following the brew.sh model: a static page plus a JSON feed, with client-side
JavaScript for search and filtering.

- **Data:** the catalog JSON lives in the `spoonify` repository, and the Pages
  site in the same repository reads it with `fetch('./index.json')`. Keeping the
  JSON same-origin avoids CORS handling and the `text/plain` content-type and
  aggressive caching of `raw.githubusercontent.com`.
- **Search:** start simple with `Array.filter` or a small fuzzy-search library
  such as Fuse.js. As the catalog grows, precompute a search index at build
  time (Eleventy, Astro, or a small script), as Homebrew does.
- **No backend:** everything is static. No server, no domain, no running cost.

## Copy Config or Lua

Each search result offers two copy actions:

- the JSON manifest snippet, and
- the equivalent Lua builder code, for example
  `SpoonManager.from.github(...).path(...).install()`.

This is the same `manifest -> definition -> Lua` mapping already shown as the
"equivalent to" examples in `spoonify-manifests.md`.

**Avoid drift.** That mapping would then exist in three places: the docs, the
Lua tool, and the website's JavaScript generator. All three should be derivable
from a single source, the JSON schema built for the `spoonify` repository. One
field schema drives both validation and code generation.

## One-Click Import via URL Scheme

For users who already run SpoonManager, the website can offer a true one-click
install using Hammerspoon's URL handling.

Hammerspoon registers the `hammerspoon://` scheme at startup. SpoonManager binds
a handler with `hs.urlevent`:

```lua
-- registered by SpoonManager
hs.urlevent.bind("spoonManagerInstall", function(eventName, params)
    -- 1. build a config from params (params.repo, params.path, params.branch, ...)
    -- 2. show a confirmation dialog (source and what will be installed)
    -- 3. on confirm: SpoonManager.from.github(params.repo).path(params.path).install()
end)
```

A catalog entry on the website becomes an install link:

```text
hammerspoon://spoonManagerInstall?repo=muescha/SpoonRepo&path=Source/Alpha.spoon&branch=main
```

A cleaner variant references a manifest instead of inlining fields, so
SpoonManager fetches and resolves the details itself:

```text
hammerspoon://spoonManagerInstall?manifest=https://raw.githubusercontent.com/owner/repo/main/spoonify.json&spoon=Alpha
```

**Precondition:** Hammerspoon is running and SpoonManager is loaded with the
binding. Bootstrapping SpoonManager itself stays manual (chicken-and-egg); every
Spoon after that can be one click.

### Security Requirements

A URL scheme that installs code is a remote-code-execution vector. A Spoon is
arbitrary Lua running with the user's full privileges, and anyone can place a
`hammerspoon://spoonManagerInstall?...` link and try to get a user to click it.

The following are requirements, not options:

- A confirmation dialog is mandatory. It must show the source (repository, path,
  branch) clearly **before** anything is downloaded.
- The confirmation should tie into the existing trust model
  (`trustManifestRemoteUrls` and the "Source Safety" section of
  `spoonify-manifests.md`), ideally with a "trust this source?" gate.
- No silent install from a click is ever allowed.

This is the same reasoning that makes the design deny remote ZIP URLs by
default; for a one-click link from an untrusted web page it applies more
strictly.

## Future In-App GUI

A GUI inside SpoonManager is feasible with Hammerspoon primitives:

- **Lightweight:** `hs.chooser` (the native quick-search picker) fed from the
  catalog, then select and `install()`. Minimal and immediate.
- **Rich:** `hs.webview` rendering an HTML app that triggers installs.

### Reusing the Hosted Website as the GUI

`hs.webview` can load a remote URL directly:

```lua
hs.webview.new(rect):url("https://muescha.github.io/spoonify/"):show()
```

This means the hosted discovery website *is* the GUI, so the UI does not need to
be built a second time inside the Spoon, and web updates appear immediately
without a new release.

The install action can reach Lua in two ways, and the choice is a security
decision:

- **JavaScript-to-Lua bridge (`hs.webview.usercontent`).** Page JavaScript posts
  a message to Lua. This is powerful, but it loads remote HTML/JavaScript into a
  privileged webview and gives remote code a direct path to the install
  function. It is the same remote-code-execution concern as the URL scheme, but
  sharper.
- **Reusing the `hammerspoon://` URL scheme (preferred).** The install button on
  the page is already a `hammerspoon://spoonManagerInstall?...` link, so a click
  inside the webview flows through the same confirmed handler as a click from a
  browser. No additional trust channel, no direct Lua access for remote
  JavaScript, and the page behaves identically in a browser and in the webview.

Remote versus locally bundled UI is a trade-off:

| | Remote webview (hosted site) | Locally bundled in the Spoon |
|---|---|---|
| Rebuild on UI change | not needed, always current | new release needed |
| Offline | requires internet | works offline |
| Version pinning | hard (the site changes independently) | UI matches the Spoon version |
| Attack surface | larger (remote code in the webview) | smaller |

Recommendation: a remote webview for display is acceptable and avoids building
the UI twice; the install action should go through the URL scheme rather than an
open JavaScript-to-Lua bridge. A locally bundled fallback UI can be added later
for offline use and version pinning, but is not required initially.

### Installing Without Editing `init.lua`

The goal of installing from the GUI without editing `init.lua` is already
supported by the planned installed registry in `registry-history-status.md`. The
registry persists successful installed state, including `config`. A GUI install
writes to the registry, and SpoonManager replays it on startup, so the user
never edits `init.lua`. The planned status fields `configuredForUse` and
`loaded` already distinguish "installed" from "loads automatically". What is
missing is the implementation plus a "load the registry on startup" hook.

## Escalation Levels

The website offers three levels of increasing convenience:

1. **Copy Lua/JSON** — manual, works for everyone, including first-time users
   without SpoonManager.
2. **`hammerspoon://` button** — one-click for users who already run
   SpoonManager.
3. **GUI** — search and install entirely inside Hammerspoon.

Levels 1 and 2 coexist: copy-paste is the discovery and first-run path, the URL
scheme is the express path for existing users.

## Status

This is future implementation work. It depends on the `spoonify` catalog repo,
the JSON schema, the manifest loading APIs (`from.spoonify(...)`), and the
installed registry, none of which are implemented yet.
