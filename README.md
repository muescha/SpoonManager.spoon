# SpoonManager.spoon

SpoonManager is an experimental Hammerspoon Spoon installer with explicit source definitions and a small builder API.

## Goals

- Install known Spoons without loading a catalog first.
- Support classic Spoon ZIPs, flat ZIPs, local folders, GitHub repository roots, GitHub folders, and GitHub release assets.
- Keep `install()` synchronous so a Hammerspoon `init.lua` can use the Spoon immediately after installation.
- Keep `install()` idempotent: if the Spoon already exists, skip the download and only apply `.use(...)` options.
- Use `update()` when the external source should be fetched again.
- Protect existing local changes by default.
- Keep catalogs optional for later search, GUI, or SpoonHub-style workflows.

## Examples

Install from the default Hammerspoon Spoons repository using the classic ZIP convention:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

Install a Spoon from a folder inside a GitHub repository:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .branch("main")
    .folder("Source/deepfolder")
    .asSpoon("DeepFolder")
    .install()
```

Install from the latest GitHub release asset:

```lua
spoon.SpoonManager.from.github("muescha/DeepFolder.spoon")
    .releaseLatest()
    .asset("DeepFolder.zip")
    .asSpoon("DeepFolder")
    .install()
```

Install from a local folder:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/DeepFolder.spoon")
    .install()
```

Add definitions and install them together:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })

local deepFolder =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .folder("Source/deepfolder")
        .asSpoon("DeepFolder")

spoon.SpoonManager.add(emojis, deepFolder)
spoon.SpoonManager.install()
```

Update explicitly:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .update()
```

## Local Changes

`install()` skips already installed Spoons.

`update()` fetches the source again. If the target Spoon exists and SpoonManager cannot prove that it is unchanged, update aborts by default.

Override per definition:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .onLocalChanges("backup")
    .install()
```

Allowed values:

- `"abort"`: default
- `"backup"`: move the existing Spoon aside first
- `"overwrite"`: replace the existing Spoon

## Notes

`catalog.json` and `spoonify.json` are intentionally not part of the install path yet. They can come later for browsing, generated source definitions, and SpoonHub-style discovery.
