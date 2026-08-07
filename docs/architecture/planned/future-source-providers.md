# Future Source Providers

This note collects provider ideas that are outside the completed source provider
pipeline migration.

## Scope

The current provider interface is ready for more source providers, but adding
them is future implementation work, not part of the provider migration itself.

Future providers should use the existing shape:

- provider metadata such as `name`, `factoryName`, and `capabilities`
- `createSource(...)` to create normal builder config
- `resolve(...)` to produce generic resolved source values such as
  `sourceKind`, `url`, `localPath`, and `extractFolder`

They should not introduce provider-specific command kinds. Commands should
continue to execute only generic `zip` and `folder` sources.

## Candidate Providers

- GitLab
- Codeberg
- Forgejo

GitHub Enterprise is likely covered by the existing GitHub provider through
`baseUrl`. It should be verified with tests and documentation before adding a
separate provider.

## Manifest Interaction

Future manifests may reference these providers through `source.type`, using the
same config shape produced by builder calls. Manifest loading remains a separate
feature from adding provider modules.
