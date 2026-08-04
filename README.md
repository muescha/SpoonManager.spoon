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

## API

### Source factories

Create source or definition builders. These calls do not install anything.

```lua
spoon.SpoonManager.from.default
spoon.SpoonManager.from.internal
spoon.SpoonManager.from.github(repository[, options])
spoon.SpoonManager.from.zip(url)
spoon.SpoonManager.from.localZip(path)
spoon.SpoonManager.from.localFolder(path)
```

`from.default` and `from.internal` point to the official Hammerspoon/Spoons repository and use this ZIP convention:

```text
Spoons/{name}.spoon.zip
```

`from.github(repository[, options])` accepts:

```lua
{
    branch = "main",
    ref = "main",
    baseUrl = "https://github.com",
}
```

### Source builder

Source builders describe where a Spoon can come from.

```lua
source.branch(name)
source.ref(name)
source.spoonZipPattern(pattern)
source.spoonFolderPattern(pattern)
source.spoon(name)
source.folder(path)
source.releaseLatest()
source.release(name)
source.asset(name)
source.asSpoon(name)
source.build()
```

`spoon(name)` creates a Spoon definition from a known Spoon name. With `from.default`, this resolves directly to:

```text
https://github.com/Hammerspoon/Spoons/raw/master/Spoons/{name}.spoon.zip
```

`folder(path)` selects a folder inside the source. For GitHub sources this installs via the generated repository archive and extracts only the selected folder.

`releaseLatest().asset(name)` resolves to GitHub's stable latest-release asset URL:

```text
https://github.com/owner/repo/releases/latest/download/name
```

### Definition builder

Definition builders describe one installable Spoon.

```lua
definition.asSpoon(name)
definition.use(options)
definition.onLocalChanges(behavior)
definition.add()
definition.install()
definition.update()
definition.build()
```

`use(options)` stores options passed to `hs.spoons.use()` after install or skip:

```lua
{
    config = {},
    hotkeys = {},
    fn = function(loadedSpoon) end,
    loglevel = "debug",
    start = true,
}
```

`onLocalChanges(behavior)` accepts:

```text
abort
backup
overwrite
```

### Manager actions

```lua
spoon.SpoonManager.add(definition[, ...])
spoon.SpoonManager.clear()
spoon.SpoonManager.install([definition[, ...]])
spoon.SpoonManager.update([definition[, ...]])
```

`add()` stores definitions in `SpoonManager.definitions`.

`install()` with arguments installs those definitions. Without arguments, it installs the added definitions.

`update()` works the same way, but fetches the external source again instead of skipping an already installed Spoon.

### Results

Single definition actions return:

```lua
result, err = definition.install()
result, err = definition.update()
```

On success:

```lua
{
    success = true,
    action = "install",
    skipped = true,
    reason = "already-installed",
    name = "Emojis",
    path = "~/.hammerspoon/Spoons/Emojis.spoon",
    source = {},
    use = {},
}
```

Batch actions return:

```lua
{
    success = true,
    action = "install",
    installed = {},
    skipped = {},
    errors = {},
}
```

### Install metadata

After a successful install or update, SpoonManager stores install metadata here:

```text
~/.hammerspoon/SpoonManager/installed.json
```

It contains the source and a checksum of the installed Spoon folder. That checksum is used to detect local changes before `update()`.

## Notes

`catalog.json` and `spoonify.json` are intentionally not part of the install path yet. They can come later for browsing, generated source definitions, and SpoonHub-style discovery.
