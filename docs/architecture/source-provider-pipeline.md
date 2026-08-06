# Source Providers and Install Pipeline

This note describes a proposed architecture for source providers, source capabilities, and the install pipeline.

It is intentionally a design note first. The current implementation still uses `source.type` values such as `github-folder`, `github-repository`, and `github-release` in the resolved and command stages. The goal of this proposal is to remove these source-specific execution cases over time and replace them with provider-based resolution plus a small generic installer pipeline.

## Problem

The current builder is flexible enough to express combinations that are either ignored or ambiguous.

Examples:

```lua
SpoonManager.from.remoteZip("https://example.com/A.zip")
    .asset("B.zip")
```

```lua
SpoonManager.from.localZip("~/Downloads/A.zip")
    .branch("main")
```

```lua
SpoonManager.from.github("owner/repo")
    .release("v1.2.3")
    .install()
```

The first two store values that do not affect the final command. The third stores a release value but does not say which release ZIP file to install.

The deeper issue is that the current model uses one broad `selection_*` group for several different concepts:

- selecting a Spoon by name from a pattern
- selecting a folder inside a repository
- selecting a release asset
- selecting a folder inside an archive

Those concepts happen at different stages. Treating them as one group creates ambiguity and forces the resolver and archive code to branch on many source-specific types.

## Goals

- Builder calls should not be silently ignored.
- The config should remain close to what the user wrote.
- Source provider capabilities should decide which builder calls are legal.
- `from.*` factories should come from registered providers.
- The resolver should dispatch to providers instead of containing large `if source.type == ...` blocks.
- The installer should execute generic source kinds: `zip` and `folder`.
- Archive extraction should be dumb: given a ZIP and an optional folder, extract it.
- Future providers such as GitLab, Codeberg, Forgejo, or GitHub Enterprise should fit the same shape.

## Terminology

### Provider

A provider describes one origin type and owns its capabilities and resolution logic.

Examples:

```text
github
remoteZip
localZip
localFolder
```

Later examples:

```text
gitlab
codeberg
forgejo
```

### Source

The source describes the working source to be materialized before installation.

Examples:

```lua
SpoonManager.from.github("owner/repo")
SpoonManager.from.remoteZip("https://example.com/A.zip")
SpoonManager.from.localZip("~/Downloads/A.zip")
SpoonManager.from.localFolder("~/Projects/SpoonRepo")
```

Source-building methods further narrow the source:

```lua
.branch("main")
.ref("v1.2.3")
.releaseLatest()
.release("v1.2.3")
.path("downloads/nightly")
.zipFile("WidgetKit.zip")
```

### Extract

After the source has been materialized, extraction selects the Spoon folder from that working source.

```lua
.useFolder("dist/WidgetKit.spoon")
```

`useFolder()` should be allowed once. It always applies to the working source, not to the provider origin.

### Target

The target describes the installed Spoon name and destination.

```lua
.to("WidgetKit")
```

`to()` is the proposed clearer replacement for `withName()`. It means "install as this Spoon name". If omitted, the name is inferred from `useFolder`, `zipFile`, `path`, or the origin.

## Proposed Builder API

### Repository Folder as Spoon

```lua
SpoonManager.from.github("owner/repo")
    .path("Source/WidgetKit.spoon")
    .install()
```

This means:

```text
GitHub repo archive
  -> source path Source/WidgetKit.spoon
  -> install that folder as a Spoon
```

### Repository ZIP File

```lua
SpoonManager.from.github("owner/repo")
    .path("downloads/nightly")
    .zipFile("WidgetKit.zip")
    .install()
```

This means:

```text
GitHub raw file downloads/nightly/WidgetKit.zip
  -> unzip
  -> infer Spoon folder
```

### Repository ZIP File with Folder Inside ZIP

```lua
SpoonManager.from.github("owner/repo")
    .path("downloads/nightly")
    .zipFile("WidgetKit.zip")
    .useFolder("dist/WidgetKit.spoon")
    .install()
```

This means:

```text
GitHub raw file downloads/nightly/WidgetKit.zip
  -> unzip
  -> use dist/WidgetKit.spoon inside that ZIP
```

### GitHub Release ZIP

```lua
SpoonManager.from.github("owner/repo")
    .releaseLatest()
    .zipFile("WidgetKit.zip")
    .install()
```

```lua
SpoonManager.from.github("owner/repo")
    .release("v1.2.3")
    .zipFile("WidgetKit.zip")
    .install()
```

Release selection without `zipFile()` should fail during resolution because GitHub releases can contain multiple assets.

### Remote ZIP

```lua
SpoonManager.from.remoteZip("https://example.com/WidgetKit.zip")
    .install()
```

```lua
SpoonManager.from.remoteZip("https://example.com/WidgetKit.zip")
    .useFolder("dist/WidgetKit.spoon")
    .install()
```

`path()`, `zipFile()`, and `release()` are not valid after `remoteZip()` because the source is already a ZIP.

### Local ZIP

```lua
SpoonManager.from.localZip("~/Downloads/WidgetKit.zip")
    .useFolder("dist/WidgetKit.spoon")
    .install()
```

### Local Folder

```lua
SpoonManager.from.localFolder("~/Projects/SpoonRepo")
    .path("Source/WidgetKit.spoon")
    .install()
```

```lua
SpoonManager.from.localFolder("~/Projects/SpoonRepo")
    .path("downloads/nightly")
    .zipFile("WidgetKit.zip")
    .useFolder("dist/WidgetKit.spoon")
    .install()
```

## Proposed Config Shape

The config should keep user input in stable sections.

```lua
{
    source = {
        type = "github",
        repository = "owner/repo",
        revision_branch = "main",
        path = "downloads/nightly",
        zipFile = "WidgetKit.zip",
    },
    extract = {
        folder = "dist/WidgetKit.spoon",
    },
    target = {
        name = "WidgetKitDev",
    },
}
```

Use camelCase source type names to match builder names:

```text
github
remoteZip
localZip
localFolder
```

Avoid kebab-case values such as `remote-zip`, `local-zip`, and `local-folder`.

## Provider Shape

A provider owns source creation, capabilities, and resolution.

```lua
local GitHub = {
    name = "github",
    factoryName = "github",

    capabilities = {
        branch = true,
        ref = true,
        path = true,
        zipFile = true,
        release = true,
        useFolder = true,
    },

    defaults = {
        baseUrl = "https://github.com",
        defaultBranch = "main",
    },
}

function GitHub.createSource(repository, options)
    return {
        type = "github",
        provider = "github",
        repository = repository,
        baseUrl = options.baseUrl or GitHub.defaults.baseUrl,
        defaultBranch = options.defaultBranch,
    }
end

function GitHub.resolve(config, context)
    -- returns a provider-resolved working source
end

return GitHub
```

Local and direct ZIP sources use the same provider interface:

```lua
local RemoteZip = {
    name = "remoteZip",
    factoryName = "remoteZip",

    capabilities = {
        useFolder = true,
    },
}

function RemoteZip.createSource(url)
    return {
        type = "remoteZip",
        url = url,
    }
end

function RemoteZip.resolve(config, context)
    return {
        source = {
            kind = "zip",
            url = config.source.url,
        },
    }
end

return RemoteZip
```

## Provider Registration

`from.*` factories should be generated from providers.

Conceptual API:

```lua
SpoonManager.registerProvider(GitHub)
SpoonManager.registerProvider(RemoteZip)
SpoonManager.registerProvider(LocalZip)
SpoonManager.registerProvider(LocalFolder)
```

Registration creates:

```lua
SpoonManager.from.github(...)
SpoonManager.from.remoteZip(...)
SpoonManager.from.localZip(...)
SpoonManager.from.localFolder(...)
```

Conceptual implementation:

```lua
function SpoonManager.registerProvider(provider)
    SpoonManager.providers[provider.name] = provider

    SpoonManager.from[provider.factoryName or provider.name] = function(...)
        return Definition.fromState({
            source = provider.createSource(...),
        })
    end
end
```

Provider sugar such as `spoonRepo()` and `spoonRepoZip()` can remain as normal functions built on top of `from.github(...)`.

## Capability Checks

Builder methods should not branch on `source.type`. They should ask the registered provider whether a capability is allowed.

Conceptual helper:

```lua
local function requireCapability(definition, capability, method, value)
    local source = definition.config.source or {}
    local provider = manager.providers[source.type]

    if not provider or not provider.capabilities[capability] then
        error(string.format(
            "%s cannot be used with source type '%s'.",
            util.createLabel(method, value),
            tostring(source.type)
        ), 3)
    end
end
```

Then builder methods stay small:

```lua
api.path = function(path)
    util.requireString(path, "Source path")

    local nextDef = util.copyTable(def)
    ensureNotComputed(nextDef, "path", path)
    requireCapability(nextDef, "path", "path", path)
    setExclusive(ensureSection(nextDef.config, "source"), "path", "path", path)
    return fromState(nextDef)
end
```

```lua
api.zipFile = function(fileName)
    util.requireZipPath(fileName, "ZIP file")
    util.requireFileName(fileName, "ZIP file")

    local nextDef = util.copyTable(def)
    ensureNotComputed(nextDef, "zipFile", fileName)
    requireCapability(nextDef, "zipFile", "zipFile", fileName)
    setExclusive(ensureSection(nextDef.config, "source"), "file", "zipFile", fileName)
    return fromState(nextDef)
end
```

```lua
api.useFolder = function(path)
    util.requireString(path, "Folder path")

    local nextDef = util.copyTable(def)
    ensureNotComputed(nextDef, "useFolder", path)
    requireCapability(nextDef, "useFolder", "useFolder", path)
    setExclusive(ensureSection(nextDef.config, "extract"), "folder", "useFolder", path)
    return fromState(nextDef)
end
```

## Resolver Pipeline

The resolver should dispatch to the provider:

```lua
function Resolver.resolveFromDefinition(definition)
    local config = definition.config or {}
    local source = config.source or {}
    local provider = manager.providers[source.type]

    if not provider then
        error("Unsupported source type: " .. tostring(source.type))
    end

    local resolved = provider.resolve(config, context)
    resolved.extract = util.copyTable(config.extract)
    resolved.installName = nameResolver.inferInstallName(config, resolved)
    return resolved
end
```

Provider resolution returns a generic working source, not installer-specific source types such as `github-folder`.

Examples:

```lua
{
    source = {
        kind = "zip",
        url = "https://github.com/owner/repo/archive/main.zip",
        extract = {
            folder = "Source/WidgetKit.spoon",
        },
    },
}
```

```lua
{
    source = {
        kind = "zip",
        url = "https://github.com/owner/repo/raw/main/downloads/WidgetKit.zip",
    },
}
```

```lua
{
    source = {
        kind = "folder",
        path = "/Users/me/Projects/SpoonRepo/Source/WidgetKit.spoon",
    },
}
```

`source.extract` is only needed when materializing the working source itself requires selecting a folder first. GitHub repository folder installs are the main case:

```text
GitHub repo archive
  -> source.extract folder
  -> working source folder
```

The top-level `extract.folder` then applies to the working source:

```text
working ZIP
  -> extract.folder
  -> Spoon folder
```

## Command Shape

The command should be executable without knowing the original provider.

```lua
{
    action = "install",
    source = {
        kind = "zip",
        url = "https://example.com/WidgetKit.zip",
        extract = {
            folder = nil,
        },
    },
    extract = {
        folder = "dist/WidgetKit.spoon",
    },
    target = {
        type = "spoon",
        name = "WidgetKit",
        path = "~/.hammerspoon/Spoons/WidgetKit.spoon",
    },
    options = {
        onLocalChanges = "abort",
    },
    use = {
        start = true,
    },
}
```

This keeps the installer generic:

```text
source zip + optional source.extract -> working source
source folder + optional source.extract -> working source
working source + optional extract.folder -> Spoon folder
copy Spoon folder to target
```

## Archive and Installer Responsibilities

Archive should not branch on provider-specific source types.

Bad:

```lua
if source.type == "github-folder" then
    ...
elseif source.type == "remoteZip" then
    ...
end
```

Better:

```lua
Archive.extractZip(zipPath, {
    folder = command.extract.folder,
})
```

The installer should know only:

```text
source.kind = "zip"
source.kind = "folder"
```

Provider-specific choices belong in provider resolution.

## Validation Rules

The builder should reject unsupported combinations early.

Suggested rules:

- `path()` requires provider capability `path`.
- `zipFile()` requires provider capability `zipFile`.
- `zipFile()` must be a file name, not a path.
- `zipFile()` must point to `.zip`.
- `release()` and `releaseLatest()` require provider capability `release`.
- `path()` and `release()`/`releaseLatest()` are mutually exclusive. Release assets are not repository paths.
- `release()` or `releaseLatest()` without `zipFile()` is incomplete and should fail during resolution.
- `useFolder()` requires provider capability `useFolder`.
- `useFolder()` may be set once.
- The install-name override may be set once.
- `spoonZipPattern()` requires provider capability `spoonZipPattern`.
- `spoonFolderPattern()` requires provider capability `spoonFolderPattern`.
- `spoon()` requires a Spoon pattern and should remain pattern-specific sugar.
- `path()` and `spoonZipPattern()`/`spoonFolderPattern()` are mutually exclusive. A pattern is only useful for `.spoon(...)`, while `path()` directly selects a source path.

The key rule is: if the user wrote a builder value, it must either affect resolution or produce a clear error.

## Problem Case Coverage

These are the known cases where the current implementation can store builder values that later do not affect execution. The provider architecture should cover each one explicitly.

| Current builder chain | Problem today | Provider model behavior |
| --- | --- | --- |
| `remoteZip(...).folder(...)` | Folder was not passed to ZIP extraction. | `folder()` is replaced by `useFolder()`. `remoteZip` has `useFolder` capability, so the folder becomes `extract.folder`. |
| `localZip(...).folder(...)` | Same as remote ZIP. | `localZip` has `useFolder` capability, so `useFolder()` becomes `extract.folder`. |
| `remoteZip(...).asset("A.zip")` | Asset is stored but cannot affect a fixed remote ZIP URL. | `asset()` is replaced by `zipFile()`. `remoteZip` does not have `zipFile` capability, so the builder rejects it. |
| `localZip(...).asset("A.zip")` | Same as remote ZIP. | `localZip` does not have `zipFile` capability, so the builder rejects it. |
| `localZip(...).branch("main")` | Branch is stored but only GitHub can use it. | `localZip` does not have `branch` capability, so the builder rejects it. |
| `remoteZip(...).branch("main")` | Same as local ZIP. | `remoteZip` does not have `branch` capability, so the builder rejects it. |
| `localFolder(...).branch("main")` | Branch is stored but local folders have no revision. | `localFolder` does not have `branch` capability, so the builder rejects it. |
| `github(...).release("v1").install()` | Release is stored, but no release asset was selected. | `release()` is allowed, but resolution fails unless `zipFile()` is also set. |
| `github(...).spoonZipPattern(...).folder(...)` | Pattern is stored but direct folder selection wins. | `folder()` is replaced by `path()`. `path()` conflicts with Spoon patterns through a source exclusive group. |
| `remoteZip(...).spoonZipPattern(...).spoon("A")` | Pattern is stored but remote ZIP cannot resolve `{name}` into another source. | `remoteZip` has no `spoonZipPattern` or `spoonFolderPattern` capability, so the builder rejects the pattern call. |

Provider capabilities should make unsupported combinations fail at the builder call whenever possible. Full-combination requirements, such as "release requires zipFile", can fail during resolution because they depend on the complete config.

## Migration Plan

Implement in small commits.

1. Rename source type values in config and tests:

```text
remote-zip   -> remoteZip
local-zip    -> localZip
local-folder -> localFolder
```

2. Introduce provider modules while preserving current behavior:

```text
lib/providers/GitHub.lua
lib/providers/RemoteZip.lua
lib/providers/LocalZip.lua
lib/providers/LocalFolder.lua
```

3. Add `SpoonManager.providers` and internal `registerProvider()`.

4. Generate `SpoonManager.from.*` factories from providers.

5. Add capability checks to builder methods.

6. Introduce new builder names:

```text
folder(...) -> path(...) or useFolder(...), depending on the intended meaning
asset(...)  -> zipFile(...)
```

Because there are no external users yet, aliases do not need to remain. `folder(...)` should be removed instead of kept as a legacy alias.

Keep `withName(...)` for the install-name override during the provider migration. Revisit the name after the provider model is implemented and the examples are updated.

7. Move provider-specific resolution from `Resolver.lua` into provider `resolve()` methods.

8. Change resolved and command output to generic source kinds:

```text
zip
folder
```

9. Simplify `Archive.lua` and `Installer.lua` so they execute generic commands only.

10. Update examples, snapshots, README, and network test configs.

11. Housekeeping: update `docs/architecture/spoonify-manifests.md` after the provider model settles. That document still uses older terms such as `folder(...)`, `withName(...)`, `remote-zip`, `local-folder`, `selection_folder`, and `selection_asset`. Do not update it too early while the provider terminology is still being implemented.

## Decisions

- `path()` and `release()`/`releaseLatest()` are mutually exclusive. Put them in the same exclusive source group so `setExclusive()` can reject mixed usage.
- `spoon()` remains pattern-only sugar. It should require `spoonZipPattern()` or `spoonFolderPattern()`.
- `spoonify.json` may provide source patterns and Spoon names. Loading such a manifest should produce the same normal pattern-based config that the builder would create manually. It should not introduce a second meaning for `spoon()`.
- `folder()` should be replaced by `path()` and `useFolder()`. Do not keep `folder()` as a legacy alias.
- `withName()` remains the install-name override for now. Reconsider naming only after the provider implementation is in place.
- Provider registration stays internal for version 1. `init.lua` can still use internal provider registration to build `SpoonManager.providers` and generate `SpoonManager.from.*`.
