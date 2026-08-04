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

## Setup

Install or symlink the Spoon into your Hammerspoon Spoons directory:

```sh
ln -s /path/to/SpoonManager.spoon ~/.hammerspoon/Spoons/SpoonManager.spoon
```

For development, use a symlink so changes in the repository are visible after a Hammerspoon reload:

```sh
ln -s /Users/muescha/Work/github.com/muescha/SpoonManager.spoon ~/.hammerspoon/Spoons/SpoonManager.spoon
```

Load SpoonManager in your `~/.hammerspoon/init.lua` before using it:

```lua
hs.loadSpoon("SpoonManager")
```

After `hs.loadSpoon("SpoonManager")`, Hammerspoon stores the returned Spoon object in:

```lua
spoon.SpoonManager
```

That is why the examples use `spoon.SpoonManager`.

Minimal setup:

```lua
hs.loadSpoon("SpoonManager")

spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

You can also keep a local variable if you prefer shorter code:

```lua
hs.loadSpoon("SpoonManager")

local SpoonManager = spoon.SpoonManager

SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

There is no separate `setup()` call right now. Loading the Spoon is enough.
Configuration is done by setting fields directly, for example:

```lua
hs.loadSpoon("SpoonManager")

spoon.SpoonManager.configDir =
    hs.configdir .. "/.config/SpoonManager"
```

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

## Name Inference

SpoonManager tries to infer the installed Spoon name when no explicit name is given.

The inferred name is normalized by removing these suffixes:

```text
.spoon.zip
.zip
.spoon
```

Examples:

| Input | Inferred Spoon name |
|---|---|
| `name.zip` | `name` |
| `name.spoon.zip` | `name` |
| `name.spoon` | `name` |
| `folder/lastfoldername` | `lastfoldername` |
| `folder/lastfoldername.spoon` | `lastfoldername` |
| `user/reponame` | `reponame` |
| `user/reponame.spoon` | `reponame` |
| `asset("name.zip")` | `name` |
| `asset("name.spoon.zip")` | `name` |

Remote ZIP URL:

```lua
spoon.SpoonManager.from.zip("https://example.com/name.spoon.zip")
    .install()
```

Installs as:

```text
name
```

Local ZIP:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/name.zip")
    .install()
```

Installs as:

```text
name
```

Local folder:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/name.spoon")
    .install()
```

Installs as:

```text
name
```

GitHub repository root:

```lua
spoon.SpoonManager.from.github("user/reponame.spoon")
    .install()
```

Installs as:

```text
reponame
```

GitHub folder:

```lua
spoon.SpoonManager.from.github("user/repo")
    .folder("Source/deepfolder.spoon")
    .install()
```

Installs as:

```text
deepfolder
```

GitHub release asset:

```lua
spoon.SpoonManager.from.github("user/repo")
    .releaseLatest()
    .asset("name.spoon.zip")
    .install()
```

Installs as:

```text
name
```

Use `.asSpoon(name)` to override the inferred name:

```lua
spoon.SpoonManager.from.github("user/repo")
    .folder("Source/deepfolder")
    .asSpoon("BetterName")
    .install()
```

Installs as:

```text
BetterName
```

## API

The API has three layers:

- source factories create a source
- source builders refine that source into a Spoon definition
- definition and manager actions install or update Spoons

All builder calls use dot notation and do not install anything until `install()` or `update()` is called.

### `SpoonManager.from.github(repository[, options])`

Creates a GitHub source builder.

`repository` is the GitHub repository in `owner/repo` form.

`options` may contain:

```lua
{
    branch = "main",
    ref = "main",
    baseUrl = "https://github.com",
}
```

Example, repository root is the Spoon:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .install()
```

This infers the Spoon name as `MySpoon`.

Example, Spoon is in a subfolder:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo", {
    branch = "main",
})
    .folder("Source/MySpoon.spoon")
    .install()
```

### `SpoonManager.from.zip(url)`

Creates a definition builder from a remote ZIP URL.

Use this when you already know the exact ZIP URL. The ZIP may contain a `.spoon` folder, a single root folder with `init.lua`, or `init.lua` directly at the ZIP root.

The Spoon name is inferred from the ZIP URL. Use `.asSpoon(name)` to override it.

Example:

```lua
spoon.SpoonManager.from.zip("https://example.com/MySpoon.zip")
    .asSpoon("MySpoon")
    .install()
```

Example, GitHub latest release asset as a plain ZIP URL:

```lua
spoon.SpoonManager.from.zip(
    "https://github.com/muescha/MySpoon.spoon/releases/latest/download/MySpoon.zip"
)
    .asSpoon("MySpoon")
    .install()
```

### `SpoonManager.from.localZip(path)`

Creates a definition builder from a local ZIP file.

`path` may use `~` when Hammerspoon can resolve it with `hs.fs.pathToAbsolute()`.

The Spoon name is inferred from the ZIP filename. Use `.asSpoon(name)` to override it.

Example:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/MySpoon.zip")
    .asSpoon("MySpoon")
    .install()
```

### `SpoonManager.from.localFolder(path)`

Creates a definition builder from a local folder.

The folder must contain an `init.lua` file. If the folder name ends in `.spoon`, the Spoon name is inferred automatically.

Example:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/MySpoon.spoon")
    .install()
```

Example, override the installed Spoon name:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/experimental")
    .asSpoon("MySpoon")
    .install()
```

### `SpoonManager.from.default`

Built-in source alias for the official Hammerspoon/Spoons repository.

It points to:

```text
Hammerspoon/Spoons
```

on branch:

```text
master
```

and uses this ZIP convention:

```text
Spoons/{name}.spoon.zip
```

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

### `source.branch(name)`

Returns a new source builder using the given branch name.

This is mostly useful for GitHub sources.

Example:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .branch("develop")
    .folder("Source/MySpoon.spoon")
    .install()
```

### `source.ref(name)`

Alias for `source.branch(name)`.

Use it when the source should be described more generally as a ref.

Example:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .ref("main")
    .folder("Source/MySpoon.spoon")
    .install()
```

### `source.spoonZipPattern(pattern)`

Returns a new source builder that knows how to turn a Spoon name into a ZIP path.

The pattern may contain `{name}`.

Example:

```lua
local repo =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .branch("main")
        .spoonZipPattern("dist/{name}.zip")

repo.spoon("MySpoon")
    .install()
```

This resolves to:

```text
https://github.com/muescha/SpoonRepo/raw/main/dist/MySpoon.zip
```

### `source.spoonFolderPattern(pattern)`

Returns a new source builder that knows how to turn a Spoon name into a folder path.

The pattern may contain `{name}`.

Example:

```lua
local repo =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .branch("main")
        .spoonFolderPattern("Source/{name}.spoon")

repo.spoon("MySpoon")
    .install()
```

### `source.spoon(name)`

Creates a Spoon definition from a known Spoon name.

With `from.default`, this resolves directly to the official Spoon ZIP:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .install()
```

Resolved URL:

```text
https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TimeMachineProgress.spoon.zip
```

With a custom ZIP pattern:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .spoonZipPattern("build/{name}.zip")
    .spoon("MySpoon")
    .install()
```

### `source.folder(path)`

Creates a Spoon definition from a folder inside the source.

For GitHub sources, SpoonManager downloads the generated repository archive and extracts only the selected folder.

Example:

```lua
spoon.SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .folder("Source/TimeMachineProgress.spoon")
    .install()
```

If the folder does not end in `.spoon`, use `asSpoon()`:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .folder("Source/deepfolder")
    .asSpoon("DeepFolder")
    .install()
```

### `source.releaseLatest()`

Returns a new GitHub release source for the latest stable release.

This does not call the GitHub API. It uses GitHub's stable latest-release download path once `asset(name)` is selected.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .releaseLatest()
    .asset("MySpoon.zip")
    .asSpoon("MySpoon")
    .install()
```

Resolved URL:

```text
https://github.com/muescha/MySpoon.spoon/releases/latest/download/MySpoon.zip
```

### `source.release(name)`

Returns a new GitHub release source for a specific release tag.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .release("v1.2.0")
    .asset("MySpoon.zip")
    .asSpoon("MySpoon")
    .install()
```

Resolved URL:

```text
https://github.com/muescha/MySpoon.spoon/releases/download/v1.2.0/MySpoon.zip
```

### `source.asset(name)`

Selects a release asset and returns a Spoon definition.

Usually used after `releaseLatest()` or `release(name)`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .releaseLatest()
    .asset("MySpoon.zip")
    .asSpoon("MySpoon")
    .install()
```

### `source.asSpoon(name)`

Creates a Spoon definition from the current source and forces the installed Spoon name.

This is useful when the repository root is the Spoon, or when the source path does not end in `.spoon`.

Example, repository root:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .asSpoon("MySpoon")
    .install()
```

Example, selected folder with custom install name:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .folder("Source/deepfolder")
    .asSpoon("DeepFolder")
    .install()
```

### `source.use(options)`

Shortcut for repository-root installs. It creates a definition from the current source, infers the name, and applies `definition.use(options)`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .use({
        start = true,
    })
    .install()
```

This is equivalent to:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .asSpoon("MySpoon")
    .use({
        start = true,
    })
    .install()
```

### `source.onLocalChanges(behavior)`

Shortcut for repository-root installs. It creates a definition from the current source, infers the name, and applies `definition.onLocalChanges(behavior)`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .onLocalChanges("backup")
    .update()
```

### `source.add()`

Shortcut for repository-root installs. It creates a definition from the current source, infers the name, and adds it to `SpoonManager.definitions`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .add()

spoon.SpoonManager.install()
```

### `source.install()`

Shortcut for repository-root installs. It creates a definition from the current source, infers the name, and installs it.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .install()
```

Installs as:

```text
MySpoon
```

### `source.update()`

Shortcut for repository-root updates. It creates a definition from the current source, infers the name, and updates it.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .update()
```

### `source.build()`

Returns the plain Lua table behind a source builder.

This is useful for debugging or for writing a future `spoonify.json`.

Example:

```lua
local source =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .branch("main")

print(hs.inspect(source.build()))
```

### `definition.asSpoon(name)`

Returns a new definition with a specific installed Spoon name.

Example:

```lua
spoon.SpoonManager.from.zip("https://example.com/download.zip")
    .asSpoon("MySpoon")
    .install()
```

### `definition.use(options)`

Returns a new definition with options that are passed to `hs.spoons.use()` after install, update, or install-skip.

Accepted options are the same style as `hs.spoons.use()`:

```lua
{
    config = {},
    hotkeys = {},
    fn = function(loadedSpoon) end,
    loglevel = "debug",
    start = true,
}
```

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .use({
        start = true,
    })
    .install()
```

Example with config and callback:

```lua
spoon.SpoonManager.from.default
    .spoon("SomeSpoon")
    .use({
        config = {
            enabled = true,
        },
        fn = function(loadedSpoon)
            print("Loaded " .. loadedSpoon.name)
        end,
    })
    .install()
```

### `definition.onLocalChanges(behavior)`

Returns a new definition with explicit behavior for existing or locally changed Spoons.

Accepted values:

```text
abort
backup
overwrite
```

`abort` is the default.

Example, backup before replacing:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges("backup")
    .update()
```

Example, force overwrite:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges("overwrite")
    .update()
```

### `definition.add()`

Adds this definition to `SpoonManager.definitions` and returns the same definition.

It does not install anything by itself.

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .use({
        start = true,
    })
    .add()

spoon.SpoonManager.install()
```

### `definition.install()`

Installs this definition synchronously.

If the Spoon is already installed, `install()` skips the download and only applies `use()` options.

Example:

```lua
local result, err =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .install()

if not result then
    print(err)
end
```

Example with use options:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .use({
        start = true,
    })
    .install()
```

### `definition.update()`

Updates this definition synchronously.

Unlike `install()`, `update()` fetches the external source again. Before replacing an existing Spoon, it checks whether the local files still match the checksum stored from the last SpoonManager install or update.

Example:

```lua
local result, err =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")
        .update()

if not result then
    print(err)
end
```

Example with backup if local files are unmanaged or changed:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges("backup")
    .update()
```

### `definition.build()`

Returns the plain Lua table behind a definition builder.

This is useful for debugging, storing definitions, or generating a future `spoonify.json`.

Example:

```lua
local definition =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })

print(hs.inspect(definition.build()))
```

### `SpoonManager.add(definition[, ...])`

Adds one or more definitions to `SpoonManager.definitions`.

It does not install anything by itself.

Example:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")

local timeMachine =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")
        .use({
            start = true,
        })

spoon.SpoonManager.add(emojis, timeMachine)
spoon.SpoonManager.install()
```

### `SpoonManager.clear()`

`clear()` removes all definitions currently stored in `SpoonManager.definitions`.
It only clears the in-memory definition list. It does not remove installed
Spoons and it does not delete install metadata from `installed.json`.

Example:

```lua
spoon.SpoonManager.add(
    spoon.SpoonManager.from.default.spoon("Emojis")
)

spoon.SpoonManager.clear()
spoon.SpoonManager.install()
```

In this example, `install()` has nothing to do after `clear()`.

### `SpoonManager.install([definition[, ...]])`

Installs definitions synchronously.

With arguments, it installs the passed definitions.

Without arguments, it installs definitions previously added with `SpoonManager.add()` or `definition.add()`.

Example with arguments:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")

spoon.SpoonManager.install(emojis)
```

Example with added definitions:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .add()

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .add()

spoon.SpoonManager.install()
```

### `SpoonManager.update([definition[, ...]])`

Updates definitions synchronously.

With arguments, it updates the passed definitions.

Without arguments, it updates definitions previously added with `SpoonManager.add()` or `definition.add()`.

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .add()

spoon.SpoonManager.update()
```

Example with explicit definition:

```lua
local timeMachine =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")

spoon.SpoonManager.update(timeMachine)
```

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
~/.hammerspoon/.config/SpoonManager/installed.json
```

It contains the source and a checksum of the installed Spoon folder. That checksum is used to detect local changes before `update()`.

The directory can be overridden:

```lua
spoon.SpoonManager.configDir =
    hs.configdir .. "/.config/SpoonManager"
```

## Notes

`catalog.json` and `spoonify.json` are intentionally not part of the install path yet. They can come later for browsing, generated source definitions, and SpoonHub-style discovery.
