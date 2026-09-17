# Changelog

All notable changes to `application-lifecycle-manager` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches a stable API.

## [Unreleased]

### Fixed
- A template that does not resolve now stops the workflow instead of creating an empty repository.
  `np template read | jq -r .url` reported nothing on failure -- jq on empty input prints nothing
  and exits 0 -- so `TEMPLATE_URL` came back empty and the providers ran with it: Bitbucket created
  the repository, left it empty and closed the hook as `success`. The call and the `url` are both
  checked now, and the error names the template and the variable the id came from.
- GitHub: a failed `mise` no longer ends the workflow. `gh` is fetched from the release tarball
  instead, into `GH_INSTALL_DIR`, and verified against the checksums GitHub publishes with the
  release. mise's attestation check fails on the nullplatform agent image
  even with working egress and an untouched rate limit, so every GitHub installation hit it on the
  first application it created.
- `capture_export` and `run_step` no longer collide with the script under test. They source it,
  and bash scopes dynamically, so their `local var` was being overwritten by any step that loops
  with `for var in ...` -- `github/build_context` does. The helper then read a different variable
  and returned a plausible wrong value instead of failing.

### Added
- `REPOSITORY_NAME_RULE` derives the repository name from the metadata filled in when the
  application is created, so the repository is born with the right name. Opt-in: without it the
  name still comes from the application's `repository_url`. `REPOSITORY_NAME_RULE_B64` carries the
  same document base64-encoded, for deployments that cannot put double quotes in an environment
  variable. A field name ending in `?` is optional and leaves no trace when blank.
- The hook callback now carries a `callback_body`, which writes to the application without racing
  the 403 window an application being created answers to `np application update`. A derived
  `repository_url` reaches the entity through it; a failed or cancelled hook sends none.
- `alm_cancel` closes the hook as `cancelled` instead of `failed`, for a step that refuses an
  operation rather than breaks on it. The reason is reported to the developer.
- Two extension points that ship doing nothing: `approve_creation`, before anything is created, and
  `scaffold_repository`, after the repository exists and before the first build.
- `GITHUB_APP_SECRET_ID` reads the GitHub App's credentials from a secrets store at run time
  instead of the agent's environment, keeping the private key out of the terraform state and the
  Helm values. The id is templated per organization, so one agent can serve several. Opt-in.
- A test suite for the GitHub code repository provider: 16 cases across all six of its steps,
  where it previously had none. `tests/stubs/gh` resolves canned responses from the same fixtures
  the curl stub uses, so a GitHub case is written the same way a Bitbucket one is.
- `CODE_REPOSITORY_DEFAULT_TEMPLATE_ID` creates an application that carries no template from a
  default one, for installations that removed the template chooser from their console. Those
  applications previously read as "importing a repository that already exists" and died at
  `validate_repository_does_not_exist` on a repository nobody had created. An application with its
  own template is never overridden, and unset the behaviour is unchanged. **Setting it removes the
  import path for the whole installation**, since the absence of a template was the only signal the
  dispatcher had for an import. `resolve_repository_name` now reads the dispatcher's
  `CODE_REPOSITORY_STRATEGY` rather than re-deriving the same decision from `template_id`, so the
  two cannot drift apart again.
- Bitbucket: `BITBUCKET_PIPELINE_FILE` chooses which pipeline file from the template is used, for templates that do not name it `bitbucket-pipelines.yml`.
- Bitbucket: `BITBUCKET_TRIGGER_PIPELINE_ENABLED=false` skips the first build after a repository is created.

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
