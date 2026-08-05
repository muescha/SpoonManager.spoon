# Definition, Resolution, and Commands

This note describes the intended internal model for SpoonManager.

The core idea is that user-facing builder calls and manifest files should produce a simple declarative definition. That definition should keep the user-provided values as close to 1:1 as possible. SpoonManager can then resolve the definition into a concrete install command as the final step.

## Goals

- Keep definitions readable and predictable.
- Avoid storing half-resolved values in the public config.
- Make `toConfig()` useful for users, agents, GUI tools, and future manifests.
- Make it possible to reconstruct a readable builder chain from a config.
- Keep installer execution separate from source description.

## Layers

### Definition

A definition describes what the user or manifest declared.

Example:

```lua
{
    name = "Emojis",
    source = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        branch = "master",
        folder = "Source/Emojis.spoon",
    },
}
```

Builder calls should map to this layer as directly as possible:

```text
from.github("owner/repo")        -> source.repository = "owner/repo"
branch("main")                  -> source.branch = "main"
ref("v1.2.3")                   -> source.ref = "v1.2.3"
folder("Source/A.spoon")        -> source.folder = "Source/A.spoon"
remoteZip(url)                  -> source.url = url
localFolder(path)               -> source.path = path
localZip(path)                  -> source.path = path
releaseLatest()                 -> source.release = "latest"
release("v1.2.3")               -> source.release = "v1.2.3"
asset("A.zip")                  -> source.asset = "A.zip"
spoonZipPattern("Spoons/{name}.spoon.zip")
                                  -> source.spoonZipPattern = "Spoons/{name}.spoon.zip"
spoonFolderPattern("Source/{name}.spoon")
                                  -> source.spoonFolderPattern = "Source/{name}.spoon"
withName("BetterName")          -> explicit target name on the definition, not the source
```

The source should answer "where does the code come from?" The installed Spoon name answers "what should this become locally?" and should stay on the definition or target layer.

### Resolved Definition

Resolution enriches a definition with derived values. These values are useful for debugging and execution, but they should not replace the original declarative input.

Example:

```lua
{
    name = "Emojis",
    source = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        branch = "master",
        folder = "Source/Emojis.spoon",
    },
    resolved = {
        sourceType = "github-folder",
        archiveUrl = "https://github.com/Hammerspoon/Spoons/archive/master.zip",
        extractFolder = "Source/Emojis.spoon",
        installName = "Emojis",
    },
}
```

Resolution is where defaults are applied. For example, GitHub may default to `main` when neither `source.branch` nor `source.ref` is set. That default does not need to be written back into the user definition.

### Command

A command is the final executable install/update task.

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

## Origin

`source.origin` should be used when a definition step resolves a more abstract source into a concrete source.

Example:

```lua
SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .spoonFolderPattern("Source/{name}.spoon")
    .spoon("Emojis")
```

Declarative source before resolution:

```lua
{
    type = "github",
    repository = "Hammerspoon/Spoons",
    branch = "master",
    spoonFolderPattern = "Source/{name}.spoon",
}
```

Concrete source after resolving the pattern:

```lua
{
    type = "github-folder",
    folder = "Source/Emojis.spoon",
    origin = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        branch = "master",
        spoonFolderPattern = "Source/{name}.spoon",
    },
}
```

The rule:

```text
origin = the source before the last resolving step
source = the concrete source after the last resolving step
```

This makes it possible to display both:

```text
Defined as:
github("Hammerspoon/Spoons").branch("master").spoonFolderPattern("Source/{name}.spoon").spoon("Emojis")

Resolved as:
github("Hammerspoon/Spoons").branch("master").folder("Source/Emojis.spoon")
```

## Folder Fields

`.folder(value)` should always set `source.folder = value`.

This avoids ambiguous meanings for `source.path`.

Recommended meaning:

```text
source.path   = local file or local base folder
source.folder = selected folder inside the source
source.url    = remote ZIP URL
```

Examples:

```lua
SpoonManager.from.github("muescha/SpoonRepo")
    .folder("Source/MySpoon.spoon")
```

```lua
source = {
    type = "github",
    repository = "muescha/SpoonRepo",
    folder = "Source/MySpoon.spoon",
}
```

```lua
SpoonManager.from.localFolder("~/Projects/SpoonRepo")
    .folder("Source/MySpoon.spoon")
```

```lua
source = {
    type = "local-folder",
    path = "/Users/example/Projects/SpoonRepo",
    folder = "Source/MySpoon.spoon",
}
```

The resolved command can join local `path` and `folder` when needed.

