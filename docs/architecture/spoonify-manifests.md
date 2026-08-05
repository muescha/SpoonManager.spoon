# Spoonify Manifests

This note describes the idea of `spoonify.json` as a declarative manifest format for SpoonManager.

`spoonify.json` should not be a resolved install command. It should describe available Spoons and their source rules. SpoonManager can then resolve the selected entries into install or update commands locally.

## Why a Manifest?

A manifest is useful when a repository contains multiple Spoons or when an external index wants to describe Spoons from repositories that do not maintain their own metadata.

Use cases:

- A Spoon repository publishes its own `spoonify.json`.
- A third-party index maintains a manifest for an inactive repository.
- A website such as "SpoonHub" or `spoonify.sh` exposes searchable Spoon metadata.
- A GUI reads manifests and lets users select Spoons to install.
- A user copies a generated SpoonManager definition into `init.lua`.

Direct installation should not require a manifest. If a user already knows the exact source, this should work without extra discovery calls:

```lua
SpoonManager.from.github("owner/repo")
    .folder("Source/A.spoon")
    .install()
```

## Repository-Level Source Rules

A compact manifest can define source rules once and then list Spoons by name.

Example, ZIP pattern:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "Hammerspoon/Spoons",
    "branch": "master",
    "spoonZipPattern": "Spoons/{name}.spoon.zip"
  },
  "spoons": [
    {
      "name": "Emojis",
      "description": "Emoji chooser"
    },
    {
      "name": "WindowSigils",
      "description": "Window switcher"
    }
  ]
}
```

The `Emojis` entry is equivalent to:

```lua
SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .spoonZipPattern("Spoons/{name}.spoon.zip")
    .spoon("Emojis")
```

Example, folder pattern:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "muescha/SpoonRepo",
    "branch": "main",
    "spoonFolderPattern": "Source/{name}.spoon"
  },
  "spoons": [
    {
      "name": "Alpha",
      "description": "First Spoon"
    },
    {
      "name": "Beta",
      "description": "Second Spoon"
    }
  ]
}
```

The `Alpha` entry is equivalent to:

```lua
SpoonManager.from.github("muescha/SpoonRepo")
    .branch("main")
    .spoonFolderPattern("Source/{name}.spoon")
    .spoon("Alpha")
```

## Per-Spoon Overrides

Each Spoon entry may override or extend the repository-level source.

Merge rule:

```text
final source = manifest.source + spoon.source
```

Example:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "muescha/SpoonRepo",
    "branch": "main",
    "spoonFolderPattern": "Source/{name}.spoon"
  },
  "spoons": [
    {
      "name": "Alpha",
      "description": "Uses the default folder pattern"
    },
    {
      "name": "DeepFolder",
      "description": "Uses a custom folder",
      "source": {
        "folder": "experimental/deepfolder"
      }
    },
    {
      "name": "ReleaseOnly",
      "description": "Uses a latest release asset",
      "source": {
        "release": "latest",
        "asset": "ReleaseOnly.zip"
      }
    }
  ]
}
```

## Source Safety

Manifests should avoid direct local filesystem paths. A public or remote `spoonify.json` must not require values such as:

```json
{
  "source": {
    "type": "local-folder",
    "path": "/Users/alice/Projects/Foo.spoon"
  }
}
```

Local paths are machine-specific and should be configured by the user, not by a remote manifest.

Provider-based sources are preferred:

```json
{
  "source": {
    "type": "github",
    "repository": "owner/repo",
    "branch": "main",
    "folder": "Source/Foo.spoon"
  }
}
```

For self-hosted providers, use `baseUrl`. This name is preferred over `host` because it includes the scheme.

GitHub Enterprise example:

```json
{
  "source": {
    "type": "github",
    "baseUrl": "https://github.company.com",
    "repository": "team/spoons",
    "branch": "main",
    "spoonFolderPattern": "Source/{name}.spoon"
  }
}
```

GitLab example:

```json
{
  "source": {
    "type": "gitlab",
    "baseUrl": "https://gitlab.company.com",
    "repository": "team/spoons",
    "branch": "main",
    "spoonFolderPattern": "Source/{name}.spoon"
  }
}
```

Forgejo or Codeberg example:

```json
{
  "source": {
    "type": "forgejo",
    "baseUrl": "https://codeberg.org",
    "repository": "user/spoons",
    "branch": "main",
    "spoonFolderPattern": "Source/{name}.spoon"
  }
}
```

Direct remote ZIP URLs inside manifests should be denied by default. They can point to arbitrary hosts, so they should require explicit trust from the user.

Possible API:

```lua
SpoonManager.trustManifestRemoteUrls(
    "https://github.com",
    "https://raw.githubusercontent.com",
    "https://spoonify.sh"
)
```

The API accepts URL-like strings but should internally trust only their origins.

```text
https://example.com/releases/Foo.zip -> https://example.com
```

Then this manifest source is allowed:

```json
{
  "source": {
    "type": "remote-zip",
    "url": "https://spoonify.sh/downloads/Foo.zip"
  }
}
```

only if the user has trusted:

```lua
SpoonManager.trustManifestRemoteUrls("https://spoonify.sh")
```

Provider-based sources such as `github`, `gitlab`, and `forgejo` do not need the remote ZIP allowlist. They are resolved by provider-specific resolver logic.

## External Manifests

`spoonify.json` should be a format, not only a file inside the source repository.

An external manifest can describe a repository that does not provide one itself:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "legacy/UsefulSpoon.spoon",
    "branch": "main"
  },
  "spoons": [
    {
      "name": "UsefulSpoon",
      "description": "Maintained externally because the upstream repository has no manifest"
    }
  ]
}
```

Possible API:

```lua
SpoonManager.from.spoonify("https://spoonify.sh/manifests/useful-spoon.json")
    .spoon("UsefulSpoon")
    .install()
```

With a local rename:

```lua
SpoonManager.from.spoonify("https://spoonify.sh/manifests/useful-spoon.json")
    .spoon("UsefulSpoon")
    .withName("MyUsefulSpoon")
    .install()
```

Installing all entries:

```lua
SpoonManager.from.spoonify("https://spoonify.sh/manifests/useful-spoon.json")
    .install()
```

## Index Manifests

A larger index can point to many `spoonify.json` files.

Example:

```json
{
  "version": 1,
  "manifests": [
    {
      "name": "official",
      "url": "https://raw.githubusercontent.com/Hammerspoon/Spoons/master/spoonify.json"
    },
    {
      "name": "muescha",
      "url": "https://raw.githubusercontent.com/muescha/SpoonRepo/main/spoonify.json"
    },
    {
      "name": "legacy-time-machine",
      "url": "https://spoonify.sh/manifests/time-machine-progress.json"
    }
  ]
}
```

Possible API:

```lua
SpoonManager.from.spoonifyIndex("https://spoonify.sh/index.json")
    .search("TimeMachine")
```

```lua
SpoonManager.from.spoonifyIndex("https://spoonify.sh/index.json")
    .spoon("TimeMachineProgress")
    .install()
```

## Manifest Versus Command

The manifest is declarative:

```text
spoonify.json -> definition
```

The manager resolves definitions locally:

```text
definition -> resolved definition -> command -> execute
```

This keeps manifests small and portable. Local values such as the final install path, `hs.configdir`, user-level `withName(...)`, and local-change behavior should be resolved by SpoonManager, not hard-coded into the manifest.
