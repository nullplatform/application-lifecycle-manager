# Contributing to application-lifecycle-manager

## Code overview

This repository is designed to run as an agent-backed workflow for nullplatform. There are two main pieces to understand before contributing: the `entrypoint` script and the workflow definitions.

### Entrypoint

At the root of the repository you will find the `entrypoint` script.

- This script is the **integration point with the nullplatform agent**.
- It receives the **notification payload** from the agent, parses the `NP_ACTION_CONTEXT`, and prepares the execution context for the workflows.
- It is responsible for:
    - Validating and parsing the notification context.
    - Triggering the appropriate workflow(s) based on the action.
    - Sending logs and results back to the nullplatform API so they can be surfaced in the platform.

Any change that affects how notifications are interpreted or how results are reported should usually touch this script.

### Workflows

This repository uses the **workflow execution tool** described in the nullplatform documentation to define, in a declarative way, the steps and scripts that need to be executed:

> https://docs.nullplatform.com/docs/agent-backed-scopes/workflows-and-execution/base-scope-workflow

Workflow definitions live under the `workflows/` directory.

Current workflows:

- `workflows/create-app.yaml`  
  This is the **main workflow**. Its responsibilities include:
    - Fetching additional data from the nullplatform API.
    - Enriching the execution context with that data.
    - Delegating to the specific workflows that handle each subtask (code repository, asset repository, etc.).

- `workflows/create_asset_repository.yaml`  
  This workflow handles the creation of the **asset repository**, as described in the “Creating an asset repository” section of the README.  
  It defines the steps required to:
    - Build the context for the asset repository provider.
    - Create the asset repository in the configured registry.
    - Persist the repository location back to the nullplatform API.

- `workflows/create_code_repository.yaml`  
  This workflow handles the creation of the **code repository**, as described in the “Creating a code repository” section of the README.  
  It defines the steps required to:
    - Build the context for the code repository provider.
    - Validate and create/import the repository.
    - Configure nullplatform credentials (CI API key).
    - Trigger the initial CI build when applicable.

When adding new functionality, you will typically either:

- Extend existing workflows with new steps, or
- Introduce new workflow files under `workflows/` and wire them to the `entrypoint` logic.

---

## Development workflow

### Extending providers

The **code repository** and **asset repository** workflows each define an *interface by convention*:  
they describe the steps that need to be executed and expect each provider implementation (for example, GitLab, Docker Server) to provide a set of scripts with specific names.

Workflows call these scripts under `scripts/` based on the selected provider.  
To add support for a new provider, you implement these scripts in the appropriate directory.

---

### Adding a new code provider

To add a new **code repository provider** (for example, `github`):

1. **Create a provider folder**

   Create a folder inside `scripts/code-repo` with the name of your provider:

   ```text
   scripts/code-repo/github/
   ```

2. **Implement the required scripts**

   Inside that folder, you must create the following executable scripts:

    - `build_context`  
      Fetch any provider-specific credentials and configuration, and export all required environment variables that subsequent steps will rely on.

    - `validate_repository_does_not_exist`  
      Call the provider API to verify that:
        - The repository does **not** already exist when creating a new repository, or
        - The repository **does** exist when the application is importing an existing repository.  
          This step should fail explicitly (non-zero exit code) when validation fails.

    - `create_repository`  
      Create the actual repository. Depending on the use case, this can:
        - Import an existing repository, or
        - Create a new one based on a template repository.

    - `create_secrets`  
      Receive a JSON payload with all the secrets that need to be created and configure them as repository secrets (key–value pairs) in the provider.  
      This is where you wire things like the nullplatform `ci` API key, registry credentials, etc.

    - `run_first_build`  
      Trigger the first build for the repository, either by:
        - Pushing a commit, or
        - Triggering a CI pipeline directly via the provider API.  
          The goal is to ensure the newly created application can be built and deployed immediately.

Once these scripts are implemented and wired correctly, the existing `create_code_repository` workflow will be able to use your provider by selecting it in the configuration.

---

### Adding a new asset provider

To add a new **asset repository provider** (for example, `s3`):

1. **Create a provider folder**

   Create a folder inside `scripts/asset-repo` with the name of your provider:

   ```text
   scripts/asset-repo/s3/
   ```

2. **Implement the required scripts**

   Inside that folder, you must create the following executable scripts:

    - `build_context`  
      Fetch any provider-specific credentials and configuration, and export all required environment variables that subsequent steps will rely on.

    - `generate_repository_uri`  
      Implement a naming strategy for the asset repository that:
        - Uniquely identifies the application.
        - Avoids collisions between different applications and environments.  
          The generated URI will be used in subsequent steps and persisted in nullplatform.

    - `create_repository`  
      Create any required objects or metadata in the repository provider (for example, buckets, paths, repositories, namespaces) and update the application settings in the nullplatform API with the final asset location.

Once these scripts are implemented, the existing `create_asset_repository` workflow will be able to use your provider without further changes to the workflow definition itself.
