# Changelog

All notable changes to `application-lifecycle-manager` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches a stable API.

## [Unreleased]

### Added
- GitHub code repository provider (GitHub App auth via the `gh` CLI).
- `CREATE_CODE_REPOSITORY` and `CREATE_ASSET_REPOSITORY` environment flags to skip code or asset
  repository creation independently. Both default to enabled, so existing behavior is unchanged.
- Bitbucket Cloud code repository support (`scripts/code-repo/bitbucket`), authenticated with a
  dedicated bot user's Atlassian API token over HTTP Basic (the only credential that can enable
  Bitbucket Pipelines).

### Changed
- The `ci` API key is now stored in the created repository as `NULLPLATFORM_API_KEY`, the name the
  nullplatform CLI reads, for every provider. It was previously stored as `NP_API_KEY`, so CI
  templates that reference that name must be updated.

### Fixed
- `bitbucket` is now recognized by the code repository provider lookup. Selecting it previously
  failed with "unknown code repository provider" unless `CODE_REPOSITORY_SPECIFICATION_ID` was set
  by hand.
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
