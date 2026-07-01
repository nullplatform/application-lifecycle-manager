# Changelog

All notable changes to `application-lifecycle-manager` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches a stable API.

## [Unreleased]

### Added
- `CREATE_CODE_REPOSITORY` and `CREATE_ASSET_REPOSITORY` flags to toggle code and asset
  repository creation independently.
- AWS ECR asset repository provider.

### Changed
- Migrated docker-server asset persistence from the deprecated `np nrn patch`
  (`docker.repository_uri`) to `np application patch` (`settings.asset.docker_server.uri`).


## [0.2.0] - 2025-11-13

### Added
- Support for loading provider credentials from environment variables.
- Support for defining default collaborators when creating code repositories.


## [0.1.0] - 2025-11-12

### Added
- Initial public version of `application-lifecycle-manager`.
- GitLab code repository support.
- Docker Server asset repository support.
