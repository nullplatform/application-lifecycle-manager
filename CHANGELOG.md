# Changelog

All notable changes to `application-lifecycle-manager` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches a stable API.

## [Unreleased]

### Added
- GitHub code repository provider (GitHub App auth via the `gh` CLI).

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

## [0.2.0] - 2025-11-13

### Added
- Support for loading provider credentials from environment variables.
- Support for defining default collaborators when creating code repositories.


## [0.1.0] - 2025-11-12

### Added
- Initial public version of `application-lifecycle-manager`.
- GitLab code repository support.
- Docker Server asset repository support.
