# application-lifecycle-manager

`application-lifecycle-manager` orchestrates and executes application lifecycle workflows.

This repository provides the code you can deploy in your own infrastructure to centralize how applications are created and managed. It focuses on two main responsibilities:

- **Managing code repositories** – defining and executing workflows to create, configure, and maintain application source code repositories.
- **Managing asset repositories** – defining and executing workflows to create, configure, and maintain repositories for application assets (such as container images or other build artifacts).

Details about specific integrations and providers are documented in later sections.

---

## What it does

This repository is built on top of the **nullplatform entity hooks** technology. Entity hooks allow you to extend the platform by defining custom behavior at specific points in an entity lifecycle (for example: *before/after creation* or *before/after update*).

`application-lifecycle-manager` uses a **pre-creation hook on the `application` entity** to orchestrate everything that needs to happen when a new application is created.

For more details about entity hooks, see the official documentation: https://docs.nullplatform.com/docs/entity-hooks/

When an application is created, this service coordinates two main tasks:

1. **Create a code repository**  
   Creates a Git repository for the application and sets up the required credentials so it can interact with the nullplatform API.

2. **Create an asset repository**  
   Creates a registry location to store application assets (for example, Docker images or serverless artifacts) and registers it in nullplatform.

---

### Creating a code repository

#### Prerequisites

You must configure your code repository provider through **nullplatform platform settings** or the **nullplatform Terraform provider**.

> **Note:** At the moment, this repository supports **GitLab** repositories only.

#### Workflow

The code repository workflow is composed of the following tasks:

- **Build context**  
  Fetches all necessary credentials and configuration for the target repository provider.

- **Validate repository**  
  Verifies that the repository does not already exist (or that it *does* exist if the application is importing an existing repository).

- **Create repository**  
  Either imports an existing repository or creates a new one based on a template repository.

- **Add collaborators**  
  Add default collaborators (users or groups) to the repository.

- **Set up nullplatform credentials**  
  Creates a nullplatform `ci` API key and associates it with the new repository so your CI/CD pipelines can create builds and push assets to the platform.

- **Trigger initial CI build**  
  Optionally kicks off a first CI build so you can deploy your application immediately after creation.

---

### Creating an asset repository

#### Prerequisites

You must configure your asset repository provider through **nullplatform platform settings** or the **nullplatform Terraform provider**.

> **Note:** At the moment, this repository supports **Docker Server** repositories only.

#### Workflow

The asset repository workflow is composed of the following tasks:

- **Build context**  
  Fetches all necessary credentials and configuration for the target asset registry.

- **Create repository**  
  Creates a namespace/folder in your Docker registry for the new application and stores its location in the nullplatform API.

---

## Installing the application lifecycle manager

This section describes how to install `application-lifecycle-manager` in your own infrastructure using the **nullplatform agent**.

The high-level flow is:

1. Ensure you have the required permissions and account information.
2. Install and configure the nullplatform agent to use this repository.
3. Create an entity hook action so that application creation events are sent to your agent.
4. Configure a notification channel that tells the agent how to execute this repository.
5. Disable the legacy workflow manager in the nullplatform API so it does not conflict with this setup.

---

### Prerequisites

Before you begin, you must:

- Have an **account-level API key** with the following permissions:
    - `Admin`
    - `ops`
    - `secops`
    - `agent`
    - `ci`
    - `developer`
    - `secret-reader`
- Fetch the **NRN** (nullplatform resource name) for the account you want to configure.

---

### Installing the agent

Follow the nullplatform agent installation guide in the official documentation:

> https://docs.nullplatform.com/docs/agent/installation

During the installation, you will be asked to set an `AGENT_REPO` variable that tells the agent which repository it should use to execute hooks.

For `application-lifecycle-manager`, you must set:

```bash
AGENT_REPO="https://github.com/nullplatform/application-lifecycle-manager#main"
```

This instructs the agent to pull and use this repository when handling the configured hooks.

---

### Create an entity hook action

Next, you need to tell the nullplatform API that you want to listen to **application creation events** and handle them via an entity hook.

You can do this using the nullplatform CLI:

```bash
np entity-hook action create --body '{
    "nrn": "<<your-account-nrn>>",
    "entity": "application",
    "action": "application:create",
    "dimensions": {},
    "when": "before",
    "type": "hook",
    "on": "create"
}'
```

This defines a **pre-creation hook** on the `application` entity. Whenever an application is about to be created, this hook will be triggered and routed according to your notification channel configuration.

---

### Configure a notification channel for your hook

Once the entity hook is defined, you must configure how nullplatform delivers the event. In this setup, we use the **nullplatform agent** as the notification target.

You can create a notification channel like this:

```bash
np notification channel create --body '
{
  "configuration": {
    "api_key": "<<your-api-key>>",
    "command": {
      "data": {
        "cmdline": "/root/.np/nullplatform/application-lifecycle-manager/entrypoint",
        "environment": {
          "NP_ACTION_CONTEXT": "'${NOTIFICATION_CONTEXT}'"
        }
      },
      "type": "exec"
    },
    "selector": {
      <<your-agent-tags>>
    }
  },
  "description": "Application lifecycle manager",
  "filters": {},
  "nrn": "<<your-nrn>>",
  "source": [
    "entity"
  ],
  "type": "agent"
}'
```

This channel configuration tells the agent:

- **Source**: It will receive notifications from `entity` events (like the `application` hook you configured).
- **Execution**: For each matching notification, it must execute the `entrypoint` script from the `application-lifecycle-manager` repository.
- **Context**: The event context is passed through the `NP_ACTION_CONTEXT` environment variable, populated from `${NOTIFICATION_CONTEXT}`.
- **Selector**: `<<your-agent-tags>>` must match the tags of the agent instance(s) that should handle these events.

---

### Disable the legacy workflow manager

By default, application creation logic is handled directly by the nullplatform API using its built-in workflow manager.  
When you move to this **agent-based strategy**, you must disable the legacy workflow manager so it does not interfere with or duplicate the operations performed by `application-lifecycle-manager`.

You can do this with the nullplatform CLI:

```bash
np nrn patch --nrn "<<your-nrn>>" --body '{
   "global.workflowSkipConfig":{
      "createCodeRepository":true,
      "createImageRepository":true,
      "setRepositorySecrets":true,
      "enableContinuousIntegration":true,
      "addMembersCodeRepository":true,
      "archiveCodeRepository":true,
      "deleteImageRegistry":true,
      "createScope":true,
      "createDeployment":false,
      "createRepositoryTag":true
   }
}'
```

This configuration instructs the nullplatform API to **skip** the built-in workflows for the operations that are now managed by `application-lifecycle-manager`, while leaving others (such as `createDeployment`) unchanged.

---

## Contributing and repository structure

To understand the internal repository structure, coding rules, and contribution guidelines, please refer to [`CONTRIBUTING.md`](./CONTRIBUTING.md).

It describes how the code is organized, how workflows are structured, and the conventions you should follow when extending `application-lifecycle-manager`.
