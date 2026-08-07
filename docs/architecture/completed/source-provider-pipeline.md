# Source Providers and Install Pipeline

This note describes the completed architecture for source providers, source capabilities, and the install pipeline.

The implementation uses provider-based resolution and generic command source kinds (`zip` and `folder`). Future provider ideas live in `../planned/future-source-providers.md`; manifest loading remains a separate feature.

## Problem

The earlier builder was flexible enough to express combinations that were either ignored or ambiguous.

Examples:

```lua
SpoonManager.from.remoteZip("https://example.com/A.zip")
    .zipFile("B.zip")
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
- selecting a release ZIP
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
.withName("WidgetKit")
```

`withName()` is the explicit install-name override. If omitted, the name is inferred from `useFolder`, `zipFile`, `path`, or the origin.

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
    -- returns provider-resolved source values
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

function RemoteZip.resolve(config)
    local extract = config.extract or {}

    return {
        sourceKind = "zip",
        url = config.source.url,
        extractFolder = extract.folder,
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
    local extract = config.extract or {}
    local target = config.target or {}
    local selectedSpoonName = nameResolver.infer(target.selection_spoon, "selected Spoon name")
    local provider = manager.providers[source.type]

    if not provider then
        error("Unsupported source type: " .. tostring(source.type))
    end

    local resolved = {
        installName = nameResolver.infer(target.name_withName, "explicit Spoon name")
            or selectedSpoonName
            or nameResolver.infer(extract.folder, "extract folder")
            or nameResolver.infer(source.zipFile, "ZIP file")
            or nameResolver.infer(source.path, "source path")
            or nameResolver.inferFromSource(source),
    }

    resolved = util.mergeTables(resolved, provider.resolve(config, {
        selectedSpoonName = selectedSpoonName,
    }))
    return resolved
end
```

Provider resolution returns generic source values, not installer-specific source types such as `github-folder`.

Examples:

```lua
{
    sourceKind = "zip",
    url = "https://github.com/owner/repo/archive/main.zip",
    extractFolder = "Source/WidgetKit.spoon",
}
```

```lua
{
    sourceKind = "zip",
    url = "https://github.com/owner/repo/raw/main/downloads/WidgetKit.zip",
}
```

```lua
{
    sourceKind = "folder",
    localPath = "/Users/me/Projects/SpoonRepo/Source/WidgetKit.spoon",
}
```

`extractFolder` is only needed when materializing the working source requires selecting a folder from an archive. GitHub repository folder installs are the main case:

```text
GitHub repo archive
  -> extractFolder
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

These are the known cases where the earlier implementation could store builder values that later did not affect execution. The provider architecture covers each one explicitly.

| Earlier builder chain | Earlier problem | Provider model behavior |
| --- | --- | --- |
| `remoteZip(...).folder(...)` | Folder was not passed to ZIP extraction. | `folder()` is replaced by `useFolder()`. `remoteZip` has `useFolder` capability, so the folder becomes `extract.folder`. |
| `localZip(...).folder(...)` | Same as remote ZIP. | `localZip` has `useFolder` capability, so `useFolder()` becomes `extract.folder`. |
| `remoteZip(...).zipFile("A.zip")` | A second ZIP file cannot affect a fixed remote ZIP URL. | `remoteZip` does not have `zipFile` capability, so the builder rejects it. |
| `localZip(...).zipFile("A.zip")` | Same as remote ZIP. | `localZip` does not have `zipFile` capability, so the builder rejects it. |
| `localZip(...).branch("main")` | Branch is stored but only GitHub can use it. | `localZip` does not have `branch` capability, so the builder rejects it. |
| `remoteZip(...).branch("main")` | Same as local ZIP. | `remoteZip` does not have `branch` capability, so the builder rejects it. |
| `localFolder(...).branch("main")` | Branch is stored but local folders have no revision. | `localFolder` does not have `branch` capability, so the builder rejects it. |
| `github(...).release("v1").install()` | Release is stored, but no release ZIP was selected. | `release()` is allowed, but resolution fails unless `zipFile()` is also set. |
| `github(...).spoonZipPattern(...).folder(...)` | Pattern is stored but direct folder selection wins. | `folder()` is replaced by `path()`. `path()` conflicts with Spoon patterns through a source exclusive group. |
| `remoteZip(...).spoonZipPattern(...).spoon("A")` | Pattern is stored but remote ZIP cannot resolve `{name}` into another source. | `remoteZip` has no `spoonZipPattern` or `spoonFolderPattern` capability, so the builder rejects the pattern call. |

Provider capabilities should make unsupported combinations fail at the builder call whenever possible. Full-combination requirements, such as "release requires zipFile", can fail during resolution because they depend on the complete config.

## Migration Status

Implemented in small commits:

1. Source type values in config and tests were renamed:

```text
remote-zip   -> remoteZip
local-zip    -> localZip
local-folder -> localFolder
```

2. Provider modules were introduced:

```text
lib/providers/GitHub.lua
lib/providers/RemoteZip.lua
lib/providers/LocalZip.lua
lib/providers/LocalFolder.lua
```

3. `SpoonManager.providers` and internal `registerProvider()` were added.

4. `SpoonManager.from.*` factories are generated from providers.

5. Builder methods use provider capability checks.

6. Ambiguous builder names were replaced:

```text
folder(...) -> path(...) or useFolder(...), depending on the intended meaning
release file selection -> zipFile(...)
```

No legacy aliases are kept for the replaced builder methods.

`withName(...)` remains the install-name override by decision. It continues to store `target.name_withName` so the existing exclusive target-name group records which builder method set the name.

7. Provider-specific resolution moved from `Resolver.lua` into provider `resolve()` methods.

8. Resolved and command output now use generic source kinds:

```text
zip
folder
```

9. `Archive.lua` and `Installer.lua` execute generic command sources only.

10. Examples, snapshots, README, and network test configs were updated.

The source provider pipeline migration is complete.

Follow-up work is tracked separately:

- future provider ideas: `../planned/future-source-providers.md`
- manifest concepts: `../planned/spoonify-manifests.md`

## Decisions

- `path()` and `release()`/`releaseLatest()` are mutually exclusive. Put them in the same exclusive source group so `setExclusive()` can reject mixed usage.
- `spoon()` remains pattern-only sugar. It should require `spoonZipPattern()` or `spoonFolderPattern()`.
- `spoonify.json` may provide source patterns and Spoon names. Loading such a manifest should produce the same normal pattern-based config that the builder would create manually. It should not introduce a second meaning for `spoon()`.
- `folder()` should be replaced by `path()` and `useFolder()`. Do not keep `folder()` as a legacy alias.
- `withName()` remains the install-name override. It intentionally keeps `target.name_withName` for the exclusive name-setting group.
- Provider registration stays internal for version 1. `init.lua` can still use internal provider registration to build `SpoonManager.providers` and generate `SpoonManager.from.*`.
