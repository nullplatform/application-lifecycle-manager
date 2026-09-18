# Changelog

All notable changes to `application-lifecycle-manager` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches a stable API.

## [Unreleased]

### Added
- `TRIGGER_SCAFFOLD_SCRIPT` points `scaffold_repository` at a scaffolding script of the operator's
  own, by absolute path on the agent host, so the step no longer has to be edited to be used.
  Opt-in: without it the step stays a no-op. The script runs as a subprocess, in an empty working
  directory that is removed afterwards, and receives the whole application document — this
  repository reads nothing out of it, so which metadata decides what gets scaffolded is entirely
  the script's business and two installations can branch on entirely different fields. A non-zero
  exit stops the workflow. `CODE_REPOSITORY_PROVIDER` is now exported for it.
- `TRIGGER_SCAFFOLD_INTERPRETER` runs that script under something other than bash -- `python3`,
  `mise exec --`, any command line on the agent's PATH. Unset, an executable script runs on its own
  shebang and a non-executable one on bash.
- `TRIGGER_SCAFFOLD_TIMEOUT` caps how long the scaffolding may take, 15 minutes by default. This is
  a `before` hook and it fails closed, so a script that hangs blocks application creation for the
  whole NRN; the ceiling is on that blockade, not on the work. stdin is closed for the same reason,
  and a script deaf to SIGTERM is killed thirty seconds later. Where `timeout` is missing from the
  agent image the step says so and runs unbounded rather than refusing to scaffold.
- Add rule engine to generate repository name
- Add hook to call client-owned repository scaffolding script
- Test suite for the GitHub code repository provider.

### Fixed
- A template that does not resolve now stops the workflow instead of creating an empty repository.
- GitHub: `gh` is installed from the release tarball instead of `mise`, whose attestation check
  fails on the nullplatform agent image.

### Fixed
- `CODE_REPOSITORY_DEFAULT_TEMPLATE_ID` now overrides the template the application carries instead
  of only filling in an empty one. It exists for installations that hide the template chooser, and
  a console with the chooser hidden still sends a `template_id` — the platform's global default —
  so the variable could never be reached from the one installation it was written for. Unset it
  changes nothing and the application's own template is used, so an installation that shows the
  chooser is unaffected. Installations that set it *and* show the chooser now have the developer's
  choice overridden, which is the behaviour change.

## [0.3.0] - 2026-08-04

### Added
- GitHub code repository provider (GitHub App auth via the `gh` CLI).
- Bitbucket Cloud code repository provider, authenticated with a dedicated bot user's Atlassian API
  token.
- Code and asset repository creation can each be skipped from the platform, through the
  `global.workflowSkipConfig` NRN key (`createCodeRepository` / `createImageRepository`, where `true`
  means skip). The `CREATE_CODE_REPOSITORY` and `CREATE_ASSET_REPOSITORY` environment variables still
  work and now override the platform in both directions. Both default to enabled, so existing
  behavior is unchanged.

### Changed
- The `ci` API key is now stored in the created repository as `NULLPLATFORM_API_KEY`, the name the
  nullplatform CLI reads, for every provider. It was previously stored as `NP_API_KEY`, so CI
  templates that reference that name must be updated.

### Fixed
- The code repository configuration is now selected by matching the provider's specification ID
  instead of taking the first result. Accounts with more than one code repository configuration
  no longer risk picking a configuration that belongs to a different provider.
- Selecting a code repository provider that has no scripts in this repository now fails immediately
  with an explicit message, instead of failing part-way through the workflow.
- The GitLab provider now fails with an explicit error when a setup value cannot be resolved,
  instead of using the literal string `null` (which made it search for a group named `null`).
- A code repository configuration that defines no default collaborators no longer breaks the
  collaborators step; the empty case is normalized to an empty list.
- A failed `ci` API key creation now stops the workflow and reports the API response. It previously
  went unnoticed and published a repository secret holding the literal string `null`.

## [0.2.0] - 2025-11-13

### Added
- Support for loading provider credentials from environment variables.
- Support for defining default collaborators when creating code repositories.


## [0.1.0] - 2025-11-12

### Added
- Initial public version of `application-lifecycle-manager`.
- GitLab code repository support.
- Docker Server asset repository support.
