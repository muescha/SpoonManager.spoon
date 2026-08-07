# Registry, History, and Status

This note describes how SpoonManager should separate installed state from install/update attempts.

## Principle

The installed registry should describe the last known successful installed state.

It should not be overwritten with failed update or install attempts.

Why:

- A failed update does not mean the old Spoon disappeared.
- The installed record should answer "what is installed now?"
- Errors are events, not the installed state itself.
- Keeping failed attempts separate avoids stale or confusing registry data.

## Installed Record

The installed record belongs in the persistent local registry.

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

This record is updated only after a successful install or update.

## Runtime Result

Each action should return a result object.

Success:

```lua
{
    success = true,
    action = "install",
    name = "Emojis",
    config = { ... },
    resolved = { ... },
    command = { ... },
    installed = { ... },
}
```

Failure:

```lua
{
    success = false,
    action = "update",
    name = "Emojis",
    stage = "download",
    error = "HTTP 404",
    config = { ... },
    resolved = { ... },
    command = { ... },
}
```

The runtime result is the best place for immediate error handling.

## History

A later version may persist action attempts in a separate history file.

Possible file:

```text
~/.hammerspoon/.config/SpoonManager/history.json
```

Example event:

```lua
{
    at = "2026-08-05T03:15:00Z",
    action = "update",
    name = "Emojis",
    success = false,
    stage = "download",
    error = "HTTP 404",
    config = { ... },
    resolved = { ... },
}
```

History is useful for:

- GUI timelines
- troubleshooting
- showing recent failures
- debugging source changes
- auditing installs and updates

History should be bounded so it does not grow forever.

Possible retention options:

```lua
SpoonManager.history.maxEntries = 100
SpoonManager.history.maxEntriesPerSpoon = 10
```

## Status

A future GUI may want a compact status object.

Possible shape:

```lua
{
    name = "Emojis",
    installed = true,
    configuredForUse = false,
    loaded = false,
    localChanges = false,
    updateAvailable = nil,
    lastSuccessAt = "2026-08-05T03:12:00Z",
    lastAttemptAt = "2026-08-05T03:15:00Z",
    lastError = {
        action = "update",
        stage = "download",
        message = "HTTP 404",
        at = "2026-08-05T03:15:00Z",
    },
}
```

This can be derived from:

```text
installed registry + latest history event + current runtime state
```

Status should be treated as a view, not as the source of truth.

## Recommendation

Version 1 should keep this simple:

```text
installed registry = successful installed state
runtime result     = current action success/failure
```

Persistent history and GUI status can be added later without changing the installed registry model.
