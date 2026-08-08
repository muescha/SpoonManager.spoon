# Pipeline (Visual Reference)

A visual companion to `../completed/definition-resolution-command.md` and
`../completed/source-provider-pipeline.md`. It shows how a Spoon travels through
SpoonManager in several diagram forms. A rendered version is kept alongside this
file as `pipeline.html`.

## Rendering note

GitHub renders Mermaid in Markdown from ```mermaid code blocks. The flowchart,
grouped-flow, state, and sequence diagrams below render on GitHub. The Sankey
uses `sankey-beta`, which is newer and may not render depending on GitHub's
Mermaid version — the grouped flow is the reliable alternative there.

## 1. The canonical pipeline

Builder calls or a manifest produce a declarative `config`, enriched stage by
stage until it executes and writes an installed record.

```mermaid
flowchart LR
  B["Builder calls · from.github(...)"] --> C
  M["Manifest · spoonify.json"] --> C
  C["config"] --> R["resolved · sourceKind, url, name"]
  R --> K["command · executable task"]
  K --> A{"action"}
  A --> I["install"]
  A --> U["update"]
  I --> REC[("installed record")]
  U --> REC
```

## 2. Flows as a Sankey

Many source types funnel into one `config`, resolution splits into ZIP vs.
folder, and the action splits into install/update with their outcomes. The
widths are **schematic, not measured** — they show branching structure, not real
volumes.

```mermaid
sankey-beta

from.github,config,6
from.gitlab,config,1
from.forgejo,config,1
from.remoteZip,config,2
from.localZip,config,1
from.localFolder,config,1
manifest,config,2
config,resolved,14
resolved,ZIP source,10
resolved,folder source,4
ZIP source,command,10
folder source,command,4
command,install,9
command,update,5
install,installed new,7
install,skipped exists,2
update,updated,3
update,skipped local changes,1
update,failed,1
installed new,registry,7
updated,registry,3
```

## 3. Grouped flow (lanes)

The same flow grouped into Sources → Pipeline → Outcomes, with outcomes
colour-coded. The most readable "map", and it renders everywhere.

```mermaid
flowchart TB
  subgraph Sources
    direction TB
    G["from.github"]
    GL["from.gitlab"]
    FJ["from.forgejo"]
    RZ["from.remoteZip"]
    LZ["from.localZip"]
    LF["from.localFolder"]
    MAN["manifest"]
  end
  Sources --> C["config"]
  C --> R["resolved"]
  R -->|zip| K["command"]
  R -->|folder| K
  K --> A{"action"}
  A -->|install| IN["installed · new"]
  A -->|install| SE["skipped · exists"]
  A -->|update| UP["updated"]
  A -->|update| SL["skipped · local changes"]
  A -->|update| FA["failed"]
  IN --> REC[("registry")]
  UP --> REC
  classDef ok fill:#d4ebe6,stroke:#1c8577,color:#16232a;
  classDef warn fill:#f6ecd6,stroke:#b47a1e,color:#16232a;
  classDef bad fill:#f0dcda,stroke:#ab534d,color:#16232a;
  class IN,UP ok;
  class SE,SL warn;
  class FA bad;
```

## 4. Lifecycle (state diagram)

The pipeline as a state machine — it makes the terminal outcomes explicit.

```mermaid
stateDiagram-v2
  [*] --> config
  config --> resolved: resolve()
  resolved --> command: command()
  command --> Installing: install()
  command --> Updating: update()
  Installing --> Installed: success
  Installing --> SkippedExists: already present
  Updating --> Updated: success
  Updating --> SkippedLocalChanges: conflictStrategy = abort
  Updating --> Failed: error
  Installed --> [*]
  Updated --> [*]
  SkippedExists --> [*]
  SkippedLocalChanges --> [*]
  Failed --> [*]
```

## 5. Component interaction (sequence)

The same journey as a conversation between components over time, including the
local-changes decision branch.

```mermaid
sequenceDiagram
  autonumber
  participant U as User / Manifest
  participant B as DefinitionBuilder
  participant Rz as DefinitionResolver
  participant Cmd as Command
  participant Ins as Installer
  participant Reg as Registry
  U->>B: from.github(...).spoon(...)
  B->>B: build config
  B->>Rz: resolve()
  Rz-->>B: resolved (sourceKind, url, name)
  B->>Cmd: command("install" / "update")
  Cmd-->>B: executable task
  B->>Ins: execute
  alt local changes and conflictStrategy = abort
    Ins-->>B: skipped (protect local changes)
  else success
    Ins->>Reg: write installed record
    Reg-->>Ins: ok
    Ins-->>B: success
  end
```

## Which form for the docs?

The grouped flow (3) works best as the primary map and the state diagram (4) for
the outcomes — both render everywhere. The Sankey (2) is the eye-catcher but
earns its keep only once real counts exist; the sequence (5) suits a "how it
works internally" page.
