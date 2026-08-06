# Config, Resolution, and Commands

This note describes the intended internal model for SpoonManager.

The core idea is that user-facing builder calls and manifest files should produce a simple declarative config. The config keeps the user-provided values as close to 1:1 as possible. SpoonManager then wraps that config in a runtime definition and enriches that definition step by step until it can execute an install or update command.

## Goals

- Keep configs readable and predictable.
- Store each calculated stage once and reuse it.
- Make `toConfig()` useful for users, agents, GUI tools, and future manifests.
- Make it possible to reconstruct a readable builder chain from a config.
- Keep installer execution separate from source description.
- Avoid `_builder` metadata by validating the real config fields.

## Layers

The intended lifecycle is:

```text
config -> resolved -> command -> install/update -> installed record
```

`config` is the durable input. `definition` is the runtime wrapper that contains `config` plus optional derived stages. `resolved` is the first derived view. `command` is the complete executable task with defaults merged in. `installed` is the persistent local registry record after execution.

`explain()` is passive. It returns the current definition state only. It does not resolve names, build commands, or normalize options. To inspect later stages, call the stage explicitly first:

```lua
definition.explain()
definition.resolve().explain()
definition.command("install").explain()
```

After `resolve()`, `command()`, `install()`, or `update()` has enriched a definition, further builder changes are rejected. Start from the base definition to create another variation.

### Config

A config describes what the user or manifest declared.

Example:

```lua
{
    source = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        revision_branch = "master",
        pattern_spoonFolderPattern = "Source/{name}.spoon",
    },
    target = {
        selection_spoon = "Emojis",
    },
}
```

Builder calls should map to this layer as directly as possible:

```text
from.github("owner/repo")        -> source.repository = "owner/repo"
branch("main")                  -> source.revision_branch = "main"
ref("v1.2.3")                   -> source.revision_ref = "v1.2.3"
remoteZip(url)                  -> source.url = url
localFolder(path)               -> source.root = path
localZip(path)                  -> source.file = path
releaseLatest()                 -> source.release_releaseLatest = true
release("v1.2.3")               -> source.release_release = "v1.2.3"
spoonZipPattern("Spoons/{name}.spoon.zip")
                                  -> source.pattern_spoonZipPattern = "Spoons/{name}.spoon.zip"
spoonFolderPattern("Source/{name}.spoon")
                                  -> source.pattern_spoonFolderPattern = "Source/{name}.spoon"
spoon("A")                      -> target.selection_spoon = "A"
path("Source/A.spoon")          -> source.path = "Source/A.spoon"
zipFile("A.zip")                -> source.zipFile = "A.zip"
useFolder("dist/A.spoon")       -> extract.folder = "dist/A.spoon"
withName("BetterName")          -> target.name_withName = "BetterName"
```

The source answers "where does the code come from?" The extract section selects a folder from a materialized source. The target section answers what the Spoon should become locally.

`definition.toConfig()` returns just the inner config:

```lua
{
    source = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        revision_branch = "master",
        pattern_spoonFolderPattern = "Source/{name}.spoon",
    },
    target = {
        selection_spoon = "Emojis",
    },
}
```

### Resolved Definition

Resolution enriches a definition with derived values. These values are useful for debugging, logging, GUI previews, and command construction, but they do not replace the original declarative input.

Example:

```lua
{
    config = {
        source = {
            type = "github",
            repository = "Hammerspoon/Spoons",
            revision_branch = "master",
            pattern_spoonFolderPattern = "Source/{name}.spoon",
        },
        target = {
            selection_spoon = "Emojis",
        },
    },
    resolved = {
        sourceKind = "zip",
        url = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        extractFolder = "Source/Emojis.spoon",
        installName = "Emojis",
    },
}
```

Resolution is where source defaults are applied. For example, GitHub may default to `main` when neither `config.source.revision_branch` nor `config.source.revision_ref` is set. That default does not need to be written back into the source section; it appears in the resolved and command stages.

The resolved table is calculated once. Later stages reuse `definition.resolved` instead of inferring names and URLs again.

### Command

A command is the final executable install/update task. It is built from the definition and resolved values. It also carries install/update options and post-install `use` behavior.

Example:

```lua
{
    action = "install",
    name = "Emojis",
    from = {
        type = "zip",
        url = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        folder = "Source/Emojis.spoon",
    },
    to = {
        type = "spoon",
        name = "Emojis",
        path = "~/.hammerspoon/Spoons/Emojis.spoon",
    },
    options = {
        onLocalChanges = "abort",
    },
    use = {
        start = true,
    },
}
```

The installer should execute commands, not interpret builder history directly.

The command should stay compact, but it is the complete execution view. It should not embed the full `definition` or `resolved` view. When the command is built, it is stored as `definition.command` and reused by install/update.

### Installed Record

An installed record is written to the local SpoonManager registry after a command succeeds. It is not part of `spoonify.json`; it describes the local machine state.

Example:

```lua
{
    name = "Emojis",
    path = "~/.hammerspoon/Spoons/Emojis.spoon",
    installedAt = "2026-08-05T03:12:00Z",
    updatedAt = "2026-08-05T03:12:00Z",
    config = {
        source = {
            type = "github",
            repository = "Hammerspoon/Spoons",
            revision_branch = "master",
            pattern_spoonFolderPattern = "Source/{name}.spoon",
        },
        target = {
            selection_spoon = "Emojis",
        },
    },
    resolved = {
        sourceKind = "zip",
        url = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        extractFolder = "Source/Emojis.spoon",
        installName = "Emojis",
    },
    fingerprints = {
        localHash = "sha256:...",
        sourceRevision = "abc123",
    },
}
```

The installed record is needed for updates, local-change detection, removal, and status views such as "installed but not configured for use".

## Exclusive Groups

Some builder methods are mutually exclusive. Instead of storing a private `_builder.used` table, the real definition fields carry the group.

The flat key format is:

```text
<group>_<method>
```

Examples:

```lua
source = {
    revision_branch = "master",
    pattern_spoonZipPattern = "Spoons/{name}.spoon.zip",
}

target = {
    selection_spoon = "Emojis",
    name_withName = "MyEmojis",
}
```

The groups are:

```text
config.source.revision_*  = one of revision_branch, revision_ref
config.source.pattern_*   = one of pattern_spoonZipPattern, pattern_spoonFolderPattern
config.target.selection_* = selection_spoon for pattern-based Spoon selection
config.target.name_*      = one of name_withName
```

The builder can validate and set these groups with one generic helper.

```lua
local function findFlatGroupValue(container, group)
    local prefix = group .. "_"

    for key, value in pairs(container or {}) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix then
            return key:sub(#prefix + 1), value, key
        end
    end

    return nil, nil, nil
end

local function setExclusive(container, group, method, value)
    local existingMethod, existingValue = findFlatGroupValue(container, group)

    if existingMethod then
        error(string.format(
            "%s already set; cannot call %s.",
            Util.createLabel(existingMethod, existingValue),
            Util.createLabel(method, value)
        ), 3)
    end

    container[group .. "_" .. method] = value
end
```

Then setting a branch is just:

```lua
setExclusive(source, "revision", "branch", branchName)
```

If `source.revision_branch = "master"` already exists and the user calls `.ref("v1.2.3")`, the error can be:

```text
branch('master') already set; cannot call ref('v1.2.3').
```

Source-changing methods also need to fail after pattern-based Spoon selection has been finalized. A definition is finalized once `target.selection_spoon` exists. Keep this check explicit instead of hiding it in an overly generic setter.

```lua
local function ensureNotFinalized(definition, method, value)
    local selectedMethod, selectedValue =
        findFlatGroupValue(definition.config.target, "selection")

    if selectedMethod then
        error(string.format(
            "%s already selected; cannot call %s. Start from the base definition instead.",
            Util.createLabel(selectedMethod, selectedValue),
            Util.createLabel(method, value)
        ), 3)
    end
end
```

Source methods use two direct steps:

```lua
ensureNotFinalized(definition, "branch", branchName)
setExclusive(definition.config.source, "revision", "branch", branchName)

ensureNotFinalized(definition, "spoonFolderPattern", pattern)
setExclusive(definition.config.source, "pattern", "spoonFolderPattern", pattern)
```

Target methods use `setExclusive` directly:

```lua
setExclusive(definition.config.target, "name", "withName", spoonName)
```

## Endpoints

Endpoint methods select the concrete Spoon from the source. Pattern-based Spoon selection writes to the `target` section and finalizes source selection. Direct source methods write to `source` or `extract`.

Endpoint methods:

```text
spoon(name)
path(path)
zipFile(name)
useFolder(path)
```

After an endpoint, source-changing methods should fail. Allowed follow-up methods are target/use/install behavior and actions:

```text
withName(...)
use(...)
onLocalChanges(...)
add()
install()
update()
toConfig()
```

Example:

```lua
SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .spoonFolderPattern("Source/{name}.spoon")
    .spoon("Emojis")
```

Config:

```lua
{
    source = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        revision_branch = "master",
        pattern_spoonFolderPattern = "Source/{name}.spoon",
    },
    target = {
        selection_spoon = "Emojis",
    },
}
```

Resolved command:

```lua
{
    action = "install",
    from = {
        type = "zip",
        url = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        folder = "Source/Emojis.spoon",
    },
    to = {
        type = "spoon",
        name = "Emojis",
    },
}
```

No `origin` is needed in the config because the original config is never overwritten.

## Folder Values

`.path(value)` should always set `source.path = value`.

Recommended meaning:

```text
source.root      = local base folder
source.file      = local ZIP file
source.path      = selected path inside a repository or local folder
source.url       = remote ZIP URL
source.zipFile   = selected ZIP file from a repository or release
extract.folder   = selected folder inside a materialized ZIP/source
```

Examples:

```lua
SpoonManager.from.github("muescha/SpoonRepo")
    .path("Source/MySpoon.spoon")
```

```lua
{
    source = {
        type = "github",
        repository = "muescha/SpoonRepo",
        path = "Source/MySpoon.spoon",
    },
}
```

```lua
SpoonManager.from.localFolder("~/Projects/SpoonRepo")
    .path("Source/MySpoon.spoon")
```

```lua
{
    source = {
        type = "localFolder",
        root = "/Users/example/Projects/SpoonRepo",
        path = "Source/MySpoon.spoon",
    },
}
```

The resolved command can join local `source.root` and `source.path` when needed.

## Name Resolution

The target section contains the selected input and optional user rename. It should not duplicate derived names.

Selection methods provide the default install name:

```text
target.selection_spoon      -> infer from the selected Spoon name
source.path                 -> infer from the selected source path
source.zipFile              -> infer from the ZIP file name
extract.folder              -> infer from the extracted folder basename
source                      -> infer from the source only if no target selection exists
```

`.withName(value)` stores an explicit override:

```lua
target = {
    name_withName = "DeepFolder",
}
```

The final install name is resolved as:

```lua
target.name_withName
    or inferNameFromSelection(target)
    or inferNameFromSource(source)
```

The resolved name belongs in `resolved.installName` or the final command, not as a duplicated top-level `definition.name`.
