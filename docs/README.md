# Documentation

Project documentation for SpoonManager. Everything lives under `architecture/`,
grouped by role.

## Viewing

- **Markdown (`.md`)** renders directly on GitHub — just click the link.
- **HTML (`.html`)** is shown as source on GitHub. To see it rendered, use the
  **rendered** links below; they go through `htmlpreview.github.io`
  (`https://htmlpreview.github.io/?<file-url>`) or you can enable GitHub Pages.
  These links work once the files are pushed.
- The **pipeline diagrams** render natively in
  [`reference/pipeline.md`](architecture/reference/pipeline.md) on GitHub (from
  ```mermaid blocks). The standalone `pipeline.html` now includes a Mermaid CDN
  loader, so it also renders via the rendered link (needs internet); Mermaid v11
  there even draws the Sankey that GitHub Markdown may not.

## Architecture

Grouped by role:

- `reference/` — general technical documentation describing the current system.
- `completed/` — completed architecture work, kept as a record of the design.
- `planned/` — concepts and features that are not implemented yet.
- `roadmap/` — a numbered overview of all ideas and focused decision matrices.

### Reference — the current system

- [testing.md](architecture/reference/testing.md)
- [network-integration-tests.md](architecture/reference/network-integration-tests.md)
- [pipeline.md](architecture/reference/pipeline.md) — visual pipeline diagrams · [rendered HTML](https://htmlpreview.github.io/?https://github.com/muescha/SpoonManager.spoon/blob/main/docs/architecture/reference/pipeline.html)

### Completed — implemented design

- [source-provider-pipeline.md](architecture/completed/source-provider-pipeline.md)
- [definition-resolution-command.md](architecture/completed/definition-resolution-command.md)

### Planned — not implemented yet

- [future-source-providers.md](architecture/planned/future-source-providers.md)
- [spoonify-manifests.md](architecture/planned/spoonify-manifests.md)
- [registry-history-status.md](architecture/planned/registry-history-status.md)
- [repository-structure-and-hosting.md](architecture/planned/repository-structure-and-hosting.md)
- [discovery-website-and-gui.md](architecture/planned/discovery-website-and-gui.md)
- [local-changes-and-forking.md](architecture/planned/local-changes-and-forking.md)

### Roadmap — overview and matrices

Ideas overview — all 25 ideas with effort, benefit, and a build verdict:

| Format | English | German |
|--------|---------|--------|
| Markdown | [roadmap.en.md](architecture/roadmap/roadmap.en.md) | [roadmap.de.md](architecture/roadmap/roadmap.de.md) |
| HTML (rendered) | [roadmap.en.html](https://htmlpreview.github.io/?https://github.com/muescha/SpoonManager.spoon/blob/main/docs/architecture/roadmap/roadmap.en.html) | [roadmap.de.html](https://htmlpreview.github.io/?https://github.com/muescha/SpoonManager.spoon/blob/main/docs/architecture/roadmap/roadmap.de.html) |

Local changes and forking — focused decision matrix:

| Format | English | German |
|--------|---------|--------|
| Markdown | [matrix.en.md](architecture/roadmap/local-changes-and-forking-matrix.en.md) | [matrix.de.md](architecture/roadmap/local-changes-and-forking-matrix.de.md) |
| HTML (rendered) | [matrix.en.html](https://htmlpreview.github.io/?https://github.com/muescha/SpoonManager.spoon/blob/main/docs/architecture/roadmap/local-changes-and-forking-matrix.en.html) | [matrix.de.html](https://htmlpreview.github.io/?https://github.com/muescha/SpoonManager.spoon/blob/main/docs/architecture/roadmap/local-changes-and-forking-matrix.de.html) |
