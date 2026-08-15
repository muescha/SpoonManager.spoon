# Repeated Name Inference During Install

## Observation

The network integration log can show the same inferred Spoon name multiple
times for one test run. For example, `github-folder` currently infers
`WindowSigils` four times.

This is visible in `log.json` because name inference debug messages include a
structured stacktrace.

## Why It Happens

Historically, the four calls came from distinct paths:

1. `SpoonManager._prepareDefinition(definition, "install")`

   The network runner builds an explain artifact before installing. Calling
   the internal prepare helper resolves the definition and infers the install
   name.

2. First `definition.install()`

   The actual install prepares its own definition command. It starts from config
   and resolves the name again.

3. Second `definition.install()`

   The network runner installs the same definition a second time to verify the
   already-installed skip behavior. This prepares the command again and infers
   the name again.

4. `_rememberDefinition()` (fixed)

   After install, SpoonManager remembers the managed definition. When replacing
   an existing remembered definition, it now uses an internal name index when
   the install name is already known instead of resolving existing stored
   configs again.

## Current Stack Shapes

Typical stacktrace sources:

```text
SpoonManager._prepareDefinition(...)
  DefinitionResolver.resolveFromDefinition
  DefinitionResolver.withResolved
  DefinitionResolver.withCommand

definition.install()
  DefinitionResolver.resolveFromDefinition
  DefinitionResolver.withResolved
  DefinitionResolver.withCommand
  Installer.prepareDefinition
  DefinitionBuilder.install

_rememberDefinition() without known installName
  DefinitionResolver.resolveFromDefinition
  definitionInstallName
  _rememberDefinition
```

## Suspected Design Issue

`definitionConfig(definition)` returns only the declarative config for builder
objects. That keeps install/update deterministic: prepared values from outside
the installer are ignored and the installer prepares fresh runtime values.

`_rememberDefinition()` still resolves when no install name is supplied, such as
manual `.add(...)` calls. When install/update passes the known name, it uses the
internal name index.

## Possible Follow-Up

- Consider whether the network explain artifact should reuse install/update
  preparation output instead of preparing once for explain and once for install.
- Keep `.add(...)` name inference acceptable or add an explicit internal name
  path for batch definitions.

## Non-Goal

Do not remove name inference itself. The goal is to avoid repeated resolution
when the answer is already available in the current flow.
