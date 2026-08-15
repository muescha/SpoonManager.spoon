# Stateless Manager Actions

**Status: Planned.**

## Handoff

Start a new Codex task with:

```text
Implement docs/architecture/planned/stateless-manager-actions.md.

Work in atomic refactor commits. Keep each commit logically balanced: when a
piece of behavior is removed from one side, wire the replacement on the other
side in the same commit.

Main goals:

1. Make SpoonManager actions stateless.
2. Remove the in-memory managed definition list API and state.
3. Keep definition.install() and definition.update() as shortcuts for manager
   actions.
4. Normalize varargs and explicit list input into one internal list shape.
5. Return one result format everywhere, using runs = { ... } for individual
   executions.
6. Add SpoonManager.installed as a registry view, including both whole-registry
   actions and selection methods such as installed.spoon("Emojis").update().
7. Keep the persisted install registry; do not remove installed metadata.

Run the normal Lua test suite after each meaningful refactor slice:
/Users/muescha/.local/share/mise/installs/lua/5.4.4/bin/lua tests/run.lua
```

This note records a possible simplification of the public SpoonManager action
model: `install` and `update` should execute the definitions passed to the
current call instead of relying on hidden manager runtime state.

## Current Shape

SpoonManager currently has two modes:

1. Direct builder actions:

   ```lua
   spoon.SpoonManager.from.default.spoon("Emojis").install()
   spoon.SpoonManager.from.default.spoon("Emojis").update()
   ```

2. Managed in-memory definitions:

   ```lua
   spoon.SpoonManager.add(
       spoon.SpoonManager.from.default.spoon("Emojis"),
       spoon.SpoonManager.from.default.spoon("TimeMachineProgress")
   )

   spoon.SpoonManager.install()
   spoon.SpoonManager.update()
   ```

The second mode depends on internal manager state:

```lua
obj.definitions = {}
obj.definitionIndexByName = {}
```

`definitions` is the in-memory list of definitions managed by the current
SpoonManager runtime. `definitionIndexByName` is an auxiliary lookup table used
to replace an existing definition by install name instead of appending
duplicates.

## Problem

The in-memory managed list is convenient, but it creates a second source of
truth beside the explicit builder/config values and beside the persisted
install registry.

The core problems:

1. `SpoonManager.update()` without arguments does not show which definitions it
   will update. A caller must know what has previously been added or installed
   in this Hammerspoon runtime.

2. Successful direct installs currently also remember their definitions, so a
   later argument-less update can be affected by earlier actions.

3. The manager needs extra bookkeeping (`definitionIndexByName`) to avoid
   duplicates and repeated name resolution.

4. Long-running Hammerspoon sessions can keep runtime state alive longer than
   expected. During console testing and reload cycles that hidden state can make
   behavior harder to reason about.

5. The project direction is that external input should be stripped down to a
   minimal declarative config and every action should prepare fresh runtime
   values internally. A hidden remembered definition list works against that
   simple one-way flow.

## Proposed Direction

Make SpoonManager actions stateless.

In this model, every install/update action receives the definitions it should
execute directly:

```lua
spoon.SpoonManager.install(
    spoon.SpoonManager.from.default.spoon("Emojis"),
    spoon.SpoonManager.from.default.spoon("TimeMachineProgress")
)

spoon.SpoonManager.update(
    spoon.SpoonManager.from.default.spoon("Emojis"),
    spoon.SpoonManager.from.default.spoon("TimeMachineProgress")
)
```

The builder shortcut remains:

```lua
spoon.SpoonManager.from.default.spoon("Emojis").install()
spoon.SpoonManager.from.default.spoon("Emojis").update()
```

Those builder actions are still stateless when they do not register themselves
inside `SpoonManager.definitions`. They are just convenient wrappers around the
same action pipeline.

## API Consequences

The stateless action API would keep:

```lua
definition.install()
definition.update()

spoon.SpoonManager.install(definition)
spoon.SpoonManager.update(definition)

spoon.SpoonManager.install(definitionA, definitionB)
spoon.SpoonManager.update(definitionA, definitionB)
```

It would remove or replace:

```lua
spoon.SpoonManager.add(...)
spoon.SpoonManager.install()
spoon.SpoonManager.update()
spoon.SpoonManager.clear()
spoon.SpoonManager.definitions
```

Calling `install()` or `update()` without definitions should fail clearly:

```text
SpoonManager.update requires at least one definition
```

This makes the missing input visible at the boundary instead of silently using
runtime state.

## Explicit Lists

For multiple Spoons, the caller can keep the list explicitly in `init.lua`:

```lua
local managedSpoons = {
    spoon.SpoonManager.from.default.spoon("Emojis"),
    spoon.SpoonManager.from.default.spoon("TimeMachineProgress"),
}

spoon.SpoonManager.install(managedSpoons)
spoon.SpoonManager.update(managedSpoons)
```

The list remains visible in user configuration, but SpoonManager itself does not
become the storage location for that list.

`install` and `update` should support both varargs and one explicit list table:

```lua
spoon.SpoonManager.update({
    spoon.SpoonManager.from.default.spoon("Emojis"),
    spoon.SpoonManager.from.default.spoon("TimeMachineProgress"),
})
```

Internally, varargs should be normalized to the same list representation. After
input normalization, the action runner should only deal with one shape:

```lua
{
    definitionA,
    definitionB,
}
```

That keeps batch behavior identical for both call styles.

## Registry Boundary

The persisted install registry remains important.

It stores what was actually installed:

- declarative config
- resolved source
- command/task details
- source and target fingerprints
- install status metadata

The registry is not the same thing as an in-memory action list. It answers
"what did SpoonManager install previously?", not "what did this runtime
currently add to a batch queue?".

If an "update everything already installed" workflow is needed later, it should
be explicit and registry-backed through `SpoonManager.installed`.

```lua
spoon.SpoonManager.installed.update()
spoon.SpoonManager.installed.outdated()
```

That would be different from `SpoonManager.update()` with hidden in-memory
state. It would say clearly that the input comes from the persisted registry,
not from definitions passed to the current action.

Possible convenience shortcuts can be added later, but they should delegate to
the same `installed` API instead of creating a second path:

```lua
spoon.SpoonManager.updateInstalled()
spoon.SpoonManager.outdated()
```

The exact names can be decided later. The important boundary is:

1. `SpoonManager.update(definition)` updates explicit caller-provided
   definitions.

2. `SpoonManager.installed.update()` updates definitions loaded from the
   installed registry.

3. Both paths should still run through the same action runner once their input
   list has been built.

## Result Shape

There should be one result format for all install/update entry points.

`definition.install()` and `definition.update()` should be treated as shortcuts
for:

```lua
spoon.SpoonManager.install(definition)
spoon.SpoonManager.update(definition)
```

Therefore they should return the same batch-style result shape as manager
actions. A single-definition run is just a batch with one run.

Possible shape:

```lua
{
    success = true,
    action = "update",
    runs = {
        {
            success = true,
            task = {
                config = { ... },
                resolved = { ... },
                command = { ... },
            },
            result = {
                action = "update",
                name = "Emojis",
                path = "...",
                skipped = true,
                reason = "source-unchanged",
                fingerprints = { ... },
            },
        },
    },
}
```

The large rule: always one result format.

Do not return a single-item result from `definition.install()` and a different
batch result from `SpoonManager.install(defA, defB)`. Different result shapes
make console inspection and tests harder than necessary.

## Benefits

1. One visible data flow

   The action input is always visible at the call site. There is no hidden
   dependency on previous `.add()` or `.install()` calls.

2. Less bookkeeping

   `obj.definitions`, `obj.definitionIndexByName`, replacement-by-name logic,
   and related tests can disappear.

3. Fewer stale-state surprises

   Long-running Hammerspoon sessions no longer keep an implicit managed list
   that can affect later console commands.

4. Cleaner action boundary

   Each action starts from a declarative config, prepares fresh resolved and
   command/task data internally, runs, and returns a result. Prepared values
   supplied from outside are ignored or rejected at the boundary.

5. Simpler tests

   Tests can pass the exact definitions they want to install or update. They no
   longer need to prepare and clean up manager runtime state except for global
   options.

6. Better naming honesty

   If a future API updates all installed Spoons, its name can say that directly:
   `updateInstalled`, not argument-less `update`.

## Trade-Offs

1. Less convenience for queued configuration

   Users who liked `.add(...); update()` need to keep their own explicit list
   or use varargs.

2. Possible README/API churn

   Examples that introduce a managed definition list need to change.

3. Batch ergonomics need a small helper

   To keep table input pleasant, `install` and `update` accept either varargs or
   one list table. Internally, both become the same list.

4. Future registry-backed update needs a separate design

   Removing `SpoonManager.update()` without arguments means "update all
   installed" must be introduced intentionally later through
   `SpoonManager.installed`.

## Implementation Cut

This should be done in small commits where each change removes one behavior and
rewires its caller in the same commit.

1. Rename the internal action runner.

   `installAndRememberDefinition` should become a neutral action runner such as
   `runDefinition`. `_installAndRememberDefinition` can become `_runDefinition`
   or `_runBuilderDefinition`.

2. Stop builder actions from remembering definitions.

   `definition.install()` and `definition.update()` should return the action
   result without mutating `obj.definitions`.

3. Require explicit definitions for manager actions.

   `SpoonManager.install()` and `SpoonManager.update()` should fail clearly when
   no definitions are passed.

4. Support explicit list input.

   Normalize these forms to the same internal list before running anything:

   ```lua
   SpoonManager.update(defA, defB)
   SpoonManager.update({ defA, defB })
   ```

5. Remove managed-list API and state.

   Remove `.add()`, `.clear()`, `obj.definitions`, and
   `obj.definitionIndexByName`. There is no legacy API to preserve yet, so no
   fallback, deprecation layer, or automatic conversion is needed. Treat this as
   greenfield cleanup.

6. Normalize result shape.

   Make builder and manager actions return the same batch result shape with a
   `runs = { ... }` section, even for a single definition.

7. Update tests.

   Replace stateful manager tests with direct vararg/list tests. Keep builder
   tests proving `definition.install()` and `definition.update()` still work and
   return the same result shape as manager actions.

8. Update README and architecture docs.

   Remove examples that teach `.add()` plus argument-less actions. Add explicit
   list examples instead.

9. Keep registry behavior unchanged.

   The install registry should continue to persist installed metadata after a
   successful install/update. This refactor only removes the runtime managed
   list, not installed metadata.

## Decisions

1. Support explicit lists immediately.

   Varargs and list input are both allowed at the public boundary. Varargs are
   converted into a list first, and all later code works with that list.

2. Remove managed-list APIs directly.

   `.add()`, `.clear()`, argument-less `.install()`, argument-less `.update()`,
   `obj.definitions`, and `obj.definitionIndexByName` can be removed without a
   legacy compatibility layer. There is no established external API to preserve
   yet.

3. Put registry-backed workflows under `SpoonManager.installed`.

   `SpoonManager.installed.update()` and `SpoonManager.installed.outdated()` are
   the preferred direction for actions based on the installed registry. Shortcuts
   may exist later, but they should delegate to this API.

4. Use one result format everywhere.

   `definition.install()` is a shortcut for `SpoonManager.install(definition)`,
   not a separate single-item result API. Single and batch actions should both
   return the same result structure, with the individual executions stored in a
   section such as `runs = { ... }`.

5. Build `SpoonManager.installed` as a registry view with selection.

   `installed` should be a registry view for already installed Spoons. It should
   support direct whole-registry actions:

   ```lua
   spoon.SpoonManager.installed.list()
   spoon.SpoonManager.installed.update()
   spoon.SpoonManager.installed.outdated()
   spoon.SpoonManager.installed.doctor()
   spoon.SpoonManager.installed.delete("Emojis")
   ```

   It should also support query-like selection from the beginning:

   ```lua
   spoon.SpoonManager.installed.spoon("Emojis").update()
   spoon.SpoonManager.installed.spoon("Emojis").delete()
   spoon.SpoonManager.installed.outdated().update()
   ```

   The flat methods are convenience calls for common whole-registry operations.
   The selection methods provide the more precise API surface for one item or a
   filtered collection.

   This keeps the public meaning clear:

   ```lua
   spoon.SpoonManager.update(definition)
   ```

   updates explicit caller-provided definitions, while:

   ```lua
   spoon.SpoonManager.installed.update()
   ```

   loads definitions from the installed registry and updates those entries.

## Non-Goals

1. Do not remove the persisted install registry.

2. Do not remove `definition.install()` or `definition.update()`.

3. Do not make install/update async.

4. Do not introduce catalog or discovery requirements for direct installs.

5. Do not reuse externally prepared resolved/command data. Actions should start
   from config and prepare fresh runtime state internally.
