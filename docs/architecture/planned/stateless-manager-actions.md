# Stateless Manager Actions

**Status: Planned.**

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

If table input is supported, `install`/`update` should flatten one level:

```lua
spoon.SpoonManager.update({
    spoon.SpoonManager.from.default.spoon("Emojis"),
    spoon.SpoonManager.from.default.spoon("TimeMachineProgress"),
})
```

and treat it the same as varargs.

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
be explicit and registry-backed:

```lua
spoon.SpoonManager.updateInstalled()
```

or another deliberately named API. That would be different from
`SpoonManager.update()` with hidden in-memory state.

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

   To keep table input pleasant, `install` and `update` should accept either
   varargs or one list table.

4. Future registry-backed update needs a separate design

   Removing `SpoonManager.update()` without arguments means "update all
   installed" must be introduced intentionally later.

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

   Normalize these forms to the same internal list:

   ```lua
   SpoonManager.update(defA, defB)
   SpoonManager.update({ defA, defB })
   ```

5. Remove managed-list API and state.

   Remove `.add()`, `.clear()`, `obj.definitions`, and
   `obj.definitionIndexByName` once callers and tests no longer need them.

6. Update tests.

   Replace stateful manager tests with direct vararg/list tests. Keep builder
   tests proving `definition.install()` and `definition.update()` still work.

7. Update README and architecture docs.

   Remove examples that teach `.add()` plus argument-less actions. Add explicit
   list examples instead.

8. Keep registry behavior unchanged.

   The install registry should continue to persist installed metadata after a
   successful install/update. This refactor only removes the runtime managed
   list, not installed metadata.

## Open Questions

1. Should `SpoonManager.install({ defA, defB })` be supported immediately, or
   should only varargs be accepted first?

2. Should `.add()` be removed in one breaking change, or should it first throw a
   message pointing users to explicit lists?

3. What should the future registry-backed API be called?

   Possible names:

   - `updateInstalled()`
   - `updateRegistry()`
   - `updateKnown()`
   - `updateAllInstalled()`

4. Should `definition.install()` return only the single item result, while
   `SpoonManager.install(defA, defB)` returns a batch result? This is currently
   convenient, but the result shape should stay easy to inspect in the
   Hammerspoon console.

## Non-Goals

1. Do not remove the persisted install registry.

2. Do not remove `definition.install()` or `definition.update()`.

3. Do not make install/update async.

4. Do not introduce catalog or discovery requirements for direct installs.

5. Do not reuse externally prepared resolved/command data. Actions should start
   from config and prepare fresh runtime state internally.
