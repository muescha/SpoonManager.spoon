# Definition, Resolution, and Commands

This note describes the intended internal model for SpoonManager.

The core idea is that user-facing builder calls and manifest files should produce a simple declarative definition. The definition keeps the user-provided values as close to 1:1 as possible. SpoonManager then resolves the definition into a concrete install command as the final step.

## Goals

- Keep definitions readable and predictable.
- Avoid storing half-resolved values in the public config.
- Make `toConfig()` useful for users, agents, GUI tools, and future manifests.
- Make it possible to reconstruct a readable builder chain from a config.
- Keep installer execution separate from source description.
- Avoid `_builder` metadata by validating the real definition fields.

## Layers

The intended lifecycle is:

```text
definition -> resolved definition -> command -> installed record
```

`definition` is the durable input. `resolved` is an explainable derived view. `command` is the executable task. `installed` is the persistent local registry record after execution.

### Definition

A definition describes what the user or manifest declared.

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
localFolder(path)               -> source.path = path
localZip(path)                  -> source.path = path
releaseLatest()                 -> source.release = "latest"
release("v1.2.3")               -> source.release = "v1.2.3"
spoonZipPattern("Spoons/{name}.spoon.zip")
                                  -> source.pattern_spoonZipPattern = "Spoons/{name}.spoon.zip"
spoonFolderPattern("Source/{name}.spoon")
                                  -> source.pattern_spoonFolderPattern = "Source/{name}.spoon"
spoon("A")                      -> target.selection_spoon = "A"
folder("Source/A.spoon")        -> target.selection_folder = "Source/A.spoon"
asset("A.zip")                  -> target.selection_asset = "A.zip"
withName("BetterName")          -> target.name_withName = "BetterName"
```

The source answers "where does the code come from?" The target section answers "which Spoon should be selected and what should it become locally?"

### Resolved Definition

Resolution enriches a definition with derived values. These values are useful for debugging, logging, GUI previews, and command construction, but they should not replace the original declarative input.

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
    resolved = {
        sourceType = "github-folder",
        archiveUrl = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        extractFolder = "Source/Emojis.spoon",
        installName = "Emojis",
    },
}
```

Resolution is where defaults are applied. For example, GitHub may default to `main` when neither `source.revision_branch` nor `source.revision_ref` is set. That default does not need to be written back into the user definition.

The resolved table is not the source of truth, but keeping it around is useful because SpoonManager has to compute these values anyway. It can be returned by `explain(...)`, logged during installs, shown by a future GUI, and copied into install results for troubleshooting.

### Command

A command is the final executable install/update task. It is built from the definition and resolved values.

Example:

```lua
{
    action = "install",
    from = {
        type = "github-folder",
        archiveUrl = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        folder = "Source/Emojis.spoon",
    },
    to = {
        type = "spoon",
        name = "Emojis",
        path = "~/.hammerspoon/Spoons/Emojis.spoon",
    },
}
```

The installer should execute commands, not interpret builder history directly.

### Installed Record

An installed record is written to the local SpoonManager registry after a command succeeds. It is not part of `spoonify.json`; it describes the local machine state.

Example:

```lua
{
    name = "Emojis",
    path = "~/.hammerspoon/Spoons/Emojis.spoon",
    installedAt = "2026-08-05T03:12:00Z",
    updatedAt = "2026-08-05T03:12:00Z",
    definition = {
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
        sourceType = "github-folder",
        archiveUrl = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
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
source.revision_*  = one of revision_branch, revision_ref
source.pattern_*   = one of pattern_spoonZipPattern, pattern_spoonFolderPattern
target.selection_* = one of selection_spoon, selection_folder, selection_asset
target.name_*      = one of name_withName
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

Source-changing methods also need to fail after the Spoon selection has been finalized. A definition is finalized once any `target.selection_*` endpoint exists. Keep this check explicit instead of hiding it in an overly generic setter.

```lua
local function ensureNotFinalized(definition, method, value)
    local selectedMethod, selectedValue =
        findFlatGroupValue(definition.target, "selection")

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
setExclusive(definition.source, "revision", "branch", branchName)

ensureNotFinalized(definition, "spoonFolderPattern", pattern)
setExclusive(definition.source, "pattern", "spoonFolderPattern", pattern)
```

Endpoint and target methods use `setExclusive` directly:

```lua
setExclusive(definition.target, "selection", "folder", folderPath)
setExclusive(definition.target, "name", "withName", spoonName)
```

## Endpoints

Endpoint methods select the concrete Spoon from the source. They write to the `target` section and finalize source selection.

Endpoint methods:

```text
spoon(name)
folder(path)
asset(name)
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

Definition:

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
        type = "github-folder",
        archiveUrl = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        folder = "Source/Emojis.spoon",
    },
    to = {
        type = "spoon",
        name = "Emojis",
    },
}
```

No `origin` is needed in the definition because the original definition is never overwritten.

## Folder Values

`.folder(value)` should always set `target.selection_folder = value`.

This avoids ambiguous meanings for `source.path`.

Recommended meaning:

```text
source.path             = local file or local base folder
source.url              = remote ZIP URL
target.selection_folder  = selected folder inside the source
```

Examples:

```lua
SpoonManager.from.github("muescha/SpoonRepo")
    .folder("Source/MySpoon.spoon")
```

```lua
{
    source = {
        type = "github",
        repository = "muescha/SpoonRepo",
    },
    target = {
        selection_folder = "Source/MySpoon.spoon",
    },
}
```

```lua
SpoonManager.from.localFolder("~/Projects/SpoonRepo")
    .folder("Source/MySpoon.spoon")
```

```lua
{
    source = {
        type = "local-folder",
        path = "/Users/example/Projects/SpoonRepo",
    },
    target = {
        selection_folder = "Source/MySpoon.spoon",
    },
}
```

The resolved command can join local `source.path` and `target.selection_folder` when needed.

## Name Resolution

The target section contains the selected input and optional user rename. It should not duplicate derived names.

Selection methods provide the default install name:

```text
target.selection_spoon      -> infer from the selected Spoon name
target.selection_folder     -> infer from the folder basename
target.selection_asset      -> infer from the ZIP asset name
source                      -> infer from the source only if no target selection exists
```

`.withName(value)` stores an explicit override:

```lua
target = {
    selection_folder = "Source/deepfolder",
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
