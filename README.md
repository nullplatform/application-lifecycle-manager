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

> **Note:** This repository supports **GitLab**, **GitHub** and **Bitbucket Cloud** code repositories.

The provider to use is taken from `CODE_REPOSITORY_PROVIDER`, or from the nullplatform account's
`repository_provider` when that variable is not set. The matching configuration is then selected by
its provider specification, so an account may hold configurations for several providers at once
without them interfering. If you configured a **custom** provider specification, set
`CODE_REPOSITORY_SPECIFICATION_ID` in the environment to point the lookup at it.

The lookup recognizes `github`, `gitlab`, `bitbucket` and `azure-devops`, so none of them needs
`CODE_REPOSITORY_SPECIFICATION_ID`. `azure-devops` has no scripts here yet, so selecting it fails
immediately with an explicit message instead of part-way through the workflow.

#### Bitbucket Cloud

Configure the Bitbucket code-repository provider with the attributes below, either from the
nullplatform UI or with the tofu module in [`scripts/code-repo/bitbucket/install/`](scripts/code-repo/bitbucket/install).


| Attribute | Required | Source | Notes |
|---|---|---|---|
| `setup.workspace` | yes | provider or env | The Bitbucket workspace slug. |
| `setup.project_key` | yes | provider or env | The key of the project new repositories are filed under. **Not optional**: omit it and Bitbucket silently assigns the repository to the workspace's oldest project. |
| `setup.installation_url` | no | provider or env | Defaults to `https://bitbucket.org`. Drives the web UI and git remote hosts. The REST host is separate (`BITBUCKET_API_BASE`, default `https://api.bitbucket.org/2.0`), because Bitbucket Cloud serves its API from a different host. |
| `access.collaborators` | no | provider | See the limitation below. `access.default_collaborators` is accepted too, for parity with the GitLab provider. |

The credential is **not** part of the provider configuration. Both halves of it are environment
variables on the ALM deployment:

| Environment variable | Required | Notes |
|---|---|---|
| `BITBUCKET_EMAIL` | yes | The Atlassian account email of the dedicated Bitbucket **bot user**. HTTP Basic username for the API token. |
| `BITBUCKET_API_TOKEN` | yes | The bot user's **Atlassian API token**: HTTP Basic password for the REST API and, with the git username `x-bitbucket-api-token-auth`, for git-over-HTTPS. See "credential sourcing" below. |

Two more environment variables control the **first build**. Both are read from the ALM deployment's
environment only — they are not provider attributes:

| Environment variable | Default | Notes |
|---|---|---|
| `BITBUCKET_TRIGGER_PIPELINE_ENABLED` | `true` | Set to `false` to skip triggering the first build after the repository is created. Bitbucket Pipelines is **still enabled** on the repository — only the build is not started. For customers whose CI runs elsewhere, or who prefer their own first push to start it. |
| `BITBUCKET_PIPELINE_FILE` | `bitbucket-pipelines.yml` | The file **inside the repository** (it arrives with the template seed) that holds the pipeline definition. Set it when the template names it something else, e.g. `circleci.yaml`. A path is accepted (`ci/pipelines.yml`). |

> **How `BITBUCKET_PIPELINE_FILE` works.** Bitbucket's trigger API cannot be pointed at an alternate
> configuration file — there is no such input. So when the configured name is *not* the default, ALM
> reads the file out of the branch it is about to build and triggers an
> [on-demand pipeline](https://www.atlassian.com/blog/bitbucket/on-demand-pipelines-via-api): the
> file's **contents** are posted as the request body (`Content-Type: application/yaml`). Two
> consequences. The file must contain valid **Bitbucket Pipelines** YAML, whatever it is named — a
> real CircleCI configuration will be rejected by Bitbucket. And if the file is not on the branch,
> the step warns naming *that* file and skips the build, instead of failing. When the variable is
> left at its default, nothing changes: the plain trigger is used and Bitbucket resolves
> `bitbucket-pipelines.yml` itself.

> **Authentication is a dedicated bot user's Atlassian API token.** nullplatform must hold a
> **user-scoped** credential because enabling Bitbucket Pipelines requires a two-step-verification
> (2SV) enabled *user* principal — an OAuth app (2LO) is refused there with a permanent `403`, and a
> workspace access token fails the same check. So: create a dedicated Bitbucket bot user, **enable
> Bitbucket 2SV on it** (this is Bitbucket 2SV, *not* Atlassian-account 2FA), grant it repository /
> pipeline / project admin on the workspace, and issue it an Atlassian API token. This works on
> **every** Bitbucket plan (no Premium required). Atlassian API tokens expire in ≤365 days, so rotate
> it before then. **Bitbucket app passwords are not supported** (Atlassian removed them on 2026-07-28).

> **Credential sourcing — this is where Bitbucket differs from GitLab.** The `bitbucket-configuration`
> specification declares **no credential fields at all**. That is deliberate: nullplatform clears
> secret attribute values on authenticated provider reads, so a token stored on the provider would
> come back as `null` from the `np provider list` call ALM uses to load its configuration. The GitLab
> provider only works from the platform read because its spec never marked `access_token` secret, a
> laxity not repeated here. **So `BITBUCKET_EMAIL` and `BITBUCKET_API_TOKEN` come from the ALM
> deployment's environment, and nowhere else.** The configuration fields above can also be overridden
> from the environment (`BITBUCKET_WORKSPACE`, `BITBUCKET_PROJECT_KEY`, `BITBUCKET_INSTALLATION_URL`),
> which always wins over the provider record. If the token or the email is missing, provisioning
> fails immediately with a message explaining exactly this.

**Collaborators.** A user is addressed by Atlassian `account_id`, by Bitbucket UUID (braces
included), or by workspace **nickname** — nicknames are resolved through the workspace member list,
so the same collaborator ids the platform stores for GitLab and GitHub work here. An **email address
cannot be used**: Bitbucket removed emails from its API. `type` is `user` or `group`, and `team` is
accepted as a synonym of `group` for GitHub-shaped configurations. Roles are `read`, `write` and
`admin`; the GitLab role names (`guest`, `reporter`, `developer`, `maintainer`, `owner`) are mapped
onto them.

**Limitation — collaborators must already be workspace members.** Bitbucket has no API to
invite a user to a workspace, so `add_collaborators` can only *grant repository permissions* to
principals who are already members. If a configured collaborator is not a member, repository
creation fails with an error naming them; a workspace administrator must invite them first.

**Limitation — no template import API.** Bitbucket Cloud cannot import a repository from a URL,
and forking is no longer usable. Templates are therefore seeded with a real `git clone` + `git
push`, squashed to a single initial commit. **`git` must be available on the agent host.**

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

#### A default template for applications that carry none

The dispatcher chooses between its `create` and `import` strategies by whether the application has
a `template_id`. An installation that removes the template chooser from its console produces
applications with none, which reads as "importing a repository that already exists" — the opposite
of what is happening — and the run dies at `validate_repository_does_not_exist` on a repository
nobody ever created.

`CODE_REPOSITORY_DEFAULT_TEMPLATE_ID` fills that gap. Set it on the agent and an application
without a template is created from that one instead:

```yaml
extra_envs:
  CODE_REPOSITORY_DEFAULT_TEMPLATE_ID: "1855672260"
```

An application that carries its own `template_id` is never overridden. Unset, nothing changes.

> **Setting this removes the import path for the whole installation.** The absence of a
> `template_id` was the only signal the dispatcher had for "this application is importing an
> existing repository", and the default gives that same absence a second meaning. The variable is
> agent-level, not per-application, so once it is set **every** application resolves to `create`,
> and one that points at a repository that already exists now fails at
> `validate_repository_does_not_exist` with *"Repository already exists but strategy is set to
> 'create'."* Leave it unset on installations that still import.

The id is read at run time: a template that does not resolve, or one whose record carries no `url`,
stops the workflow naming the id and the variable it came from. It is not validated when the agent
starts, so a typo surfaces on the first application created after the change.

#### Naming the repository from a rule

By default the repository name is the last segment of the application's `repository_url`, which
the platform already knows by the time the hook runs. Set `REPOSITORY_NAME_RULE` to build it from
what the hook knows about the application instead: the repository is then born with the right name,
with no rename afterwards and no `repository_url` left out of sync.

The rule is a JSON document on the ALM deployment's environment. Set it as
`REPOSITORY_NAME_RULE`, or — when the deployment cannot carry double quotes in an
environment variable — base64-encode the same document into
`REPOSITORY_NAME_RULE_B64`, which is used when the plain variable is empty. The
nullplatform agent's tofu module needs the encoded form: it renders
`KEY: "${value}"` straight into its Helm values with no escaping, so a rule with
quotes breaks the YAML before the agent starts.

```json
{
  "branches": [
    {
      "condition": { ".application.metadata.application.architecture": ".NET" },
      "naming_pattern": "{.application.metadata.application.architecture}-{.application.metadata.application.dotnet_type}-{.application.metadata.application.experience?}-{.application.metadata.application.domain}-{.application.metadata.application.subdomain}"
    },
    {
      "condition": { ".application.metadata.application.architecture": "Node" },
      "naming_pattern": "{.application.metadata.application.architecture}-{.application.metadata.application.node_type}-{.application.metadata.application.domain}-{.application.metadata.application.subdomain}"
    },
    {
      "naming_pattern": "{.namespace.slug}-{.application.slug}"
    }
  ]
}
```

`branches` is a list, tried in order, and the **first** entry whose `condition` holds wins. A
`condition` is an object of path → expected value; **all** of its entries have to match. Two numbers
are compared as numbers (`3` matches `3.0`); anything else is compared as exact strings, so `3` also
matches the `"3"` a metadata form stores. An entry with no `condition` matches anything, which makes it the fallback — and only
useful as the last entry, where it cannot shadow the ones after it. If nothing matches and there is
no fallback, the hook stops and prints what each condition compared against.

The expected value is a string, a number or a boolean. A list, an object or `null` is refused when
the rule is read — `null` in particular could never match, because a path that resolves to nothing
yields the empty string.

**The hook messages say which branch produced the name, and whether it won as the fallback.** That
line is worth reading: a condition whose path is *misspelt* is not an error — the path is well
formed, it simply resolves to nothing, so the branch does not match and the next one is tried. With
a fallback in the rule the repository is then created under the fallback's name and nothing else
reports it.

##### Paths

Both the condition keys and the `{...}` placeholders are dotted paths into the hook's context, which
is the notification plus the three documents it resolves:

| Path | What it reads |
|---|---|
| `.application` | the application, as `np application read` returns it — `.application.slug`, `.application.metadata.<key>.<field>`, `.application.template_id` |
| `.namespace` | the namespace — `.namespace.slug` |
| `.account` | the account — `.account.slug` |

So a rule can name a repository after things the application document does not carry, and the
metadata fields are reached through their specification's `metadata` key —
`.application.metadata.application.domain` for a specification whose `metadata` key is `application`,
which is not necessarily the entity name.

A path is a dotted path and nothing else: it is parsed, not evaluated as a jq program, so `.a | keys`
or `.a[0]` is refused as a rule problem rather than run. That applies to a condition's keys exactly
as it does to a placeholder — including the leading dot, which is required in both. Every branch is
checked when the rule is read, not only the one that wins, so a bad path in a branch no application
has matched yet still stops the hook.

##### Optional placeholders

A placeholder ending in `?` — `{.application.metadata.application.experience?}` — is **optional**:
when nothing is there, its segment is left out and the name closes up, with no empty segment and no
failure. Without the marker a missing value stops the workflow, which is what you want for a field
the form requires — a silently dropped segment would produce `net-app-issuance`, one short and
indistinguishable from a name that was meant to look like that.

The separators around a placeholder are literal text in the pattern, so an optional one that
disappears leaves them behind. They are collapsed with everything else (see below), which is also
why a pattern may end in a separator: `"{.namespace.slug}-{.application.slug}-"` is fine.

##### Slugification

Every value is slugified — accented latin characters transliterated (`Cañería` → `caneria`),
lowercased, each run of non-alphanumerics collapsed to a single hyphen, edges trimmed — and the
assembled name is slugified once more, which is what closes up the gaps left by optional
placeholders. That absorbs the shapes a metadata wizard produces without needing a mapping table:
`.NET` becomes `net`, `IAC Terraform` becomes `iac-terraform`, `Backend BFF` becomes `backend-bff`.

With the rule above:

| Application | Repository |
|---|---|
| `architecture=.NET`, `dotnet_type=APP`, `domain=fire`, `subdomain=issuance` | `net-app-fire-issuance` |
| the same plus `experience=gpas` | `net-app-gpas-fire-issuance` |
| `architecture=Node`, `node_type=Backend BFF`, `domain=motor`, `subdomain=claim` | `node-backend-bff-motor-claim` |
| `architecture=IAC Terraform` (no branch matches) | `<namespace-slug>-<application-slug>` |

Paths a branch does not use are ignored, so a wizard can collect more than the name needs.

A required placeholder that is missing or empty fails the hook, naming that path. A value that is an
array or an object fails the same way, as does one that slugifies to nothing — present but unusable
is always an error, optional or not, because skipping it would silently drop an answer the developer
gave. Names over GitHub's 100 character limit are rejected too; the free-text branches make that
limit reachable.

##### Setting it from terraform

`file()` returns the document as a string, and `jsonencode()` of a string wraps it in quotes and
escapes the ones inside — so `jsonencode(file("rules.json"))` hands over a JSON *string*, not a JSON
object. It passes a validity check and fails later. Read the file straight into the base64 variable
instead:

```hcl
extra_envs = {
  REPOSITORY_NAME_RULE_B64 = filebase64("${path.module}/repository_name_rules.json")
}
```

Set one or the other, not both: the plain variable wins when it is non-empty.

##### What is left alone

Two cases deliberately: an application whose strategy resolves to `import` (no `template_id` on the
application **and** no `CODE_REPOSITORY_DEFAULT_TEMPLATE_ID` on the agent), and any deployment with
no rule set. The signal is the strategy, not the `repository_url` — the console fills that in for
every application before the hook ever runs.

> **The derived URL travels back in `callback_body`.** An application being created answers
> `403 ENTITY_HOOKS.ENTITY_CREATION_HOOK_PENDING` to `np application update` for a window at the
> start of the hook — for every field and every identity, an organization admin key included. That
> is a state lock, not a permission problem, and it is narrow: measured against a real hook it lifts
> while the application is still in `pending_hook`, and the same `PATCH` then succeeds and applies.
> So the callback is not the only write the platform accepts, it is the one that does not depend on
> when a step happens to run. Once the repository exists its canonical URL is placed in the
> `callback_body` of the `PATCH` that closes the hook, and nullplatform merges it into the entity as
> it resumes. A failed hook closes with a status and no `callback_body`, because a run that stopped
> before creating the repository must not leave the application pointing at something that does not
> exist.

#### Using GitHub

To use GitHub as the code repository provider, set `CODE_REPOSITORY_PROVIDER=github` in the
agent environment along with a GitHub App's credentials:

| Variable                  | Required | Description                                                                                            |
|---------------------------|----------|--------------------------------------------------------------------------------------------------------|
| `GITHUB_APP_ID`           | yes      | The GitHub App's ID.                                                                                   |
| `GITHUB_PRIVATE_KEY`      | yes      | The GitHub App's private key (PEM).                                                                    |
| `GITHUB_INSTALLATION_ID`  | no       | The App installation ID for the target org. Falls back to `attributes.setup.installation_id` on the platform's code repository. |
| `GITHUB_ACCOUNT`          | no       | The owner/org where repositories are created. Falls back to `attributes.setup.organization` on the platform's code repository.  |

`GITHUB_INSTALLATION_ID` and `GITHUB_ACCOUNT` are resolved from the environment first and, when
absent, read from the code repository configured in nullplatform — the same precedence the GitLab
provider uses. Setting them in the environment overrides the platform values. The App credentials
(`GITHUB_APP_ID`, `GITHUB_PRIVATE_KEY`) must always come from the environment.

**Installing `gh`.** The agent host needs the `gh` CLI. When it is absent, `install_gh` tries `mise`
first and falls back to fetching the release tarball into `GH_INSTALL_DIR` (default `~/.local/bin`).
The fallback exists because mise's GitHub-attestation check fails on the nullplatform agent image
even when the download succeeds and the host has egress, which every GitHub installation would
otherwise hit on the first application it creates. `GH_CLI_VERSION` pins a version; without it the
latest release is resolved from the `/releases/latest` redirect, which costs no API rate limit.
Baking `gh` into the image skips all of this — the step notices it and does nothing.

**Keeping the private key out of the environment (optional).** Of the three values above only
`GITHUB_PRIVATE_KEY` is really secret, and in the agent's environment it travels through the
terraform state, the Helm values and every `kubectl describe`; rotating it means an apply and a pod
restart, which also freezes any application being created at that moment. Set `GITHUB_APP_SECRET_ID`
and the credentials are read at run time from a secrets store instead:

| Variable | Description |
|---|---|
| `GITHUB_APP_SECRET_ID` | The secret to read. `${GITHUB_ACCOUNT}` in it is replaced by the organization, so one agent can serve several GitHub orgs — adding one is a new secret, not a new deployment. |
| `GITHUB_APP_SECRET_STORE` | `aws` (default), the only store implemented today. |

The secret holds a JSON object whose keys are all optional, and each one only fills a value the
environment did not already provide — so the private key can live in the store while the installation
id keeps coming from the nullplatform provider:

```json
{ "app_id": "4966079", "installation_id": "162217903", "private_key": "-----BEGIN RSA PRIVATE KEY-----\n..." }
```

On AWS the agent reads it with its own IAM identity, so the role needs `secretsmanager:GetSecretValue`
on those secrets and the read shows up in CloudTrail. Without `GITHUB_APP_SECRET_ID` nothing changes:
the credentials come from the environment as before.

**Why a GitHub App (not a PAT):** the App is owned by the organization, is not tied to a
person, and needs no manual token rotation — an installation token is minted per run and
expires on its own. Install the App on your org and grant it repository **administration**,
**contents**, **secrets**, and **actions** permissions. The agent host must have `curl`, `jq`, and
`python3` with the `cryptography` package (used to sign the App JWT), plus the `gh` CLI — see
**Installing `gh`** above for how it gets there when the image does not ship it. GitHub.com only.

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

## Toggling repository creation

The two responsibilities are independent, so either one can be disabled. There are two ways to
do it, and they compose: the platform decides by default, and the agent's environment can
override it.

### From the platform

Each step reads the `global.workflowSkipConfig` NRN key for the application being created:

```bash
np nrn read --nrn "$applicationNrn" --ids global.workflowSkipConfig --format json
```

The value is a JSON object where **`true` means skip**:

```json
{ "createCodeRepository": true, "createRepositoryTag": true, "createImageRepository": true }
```

| Key | Step |
|---|---|
| `createCodeRepository` | code repository creation |
| `createImageRepository` | asset repository creation (the platform calls it the image repository) |

`createRepositoryTag` belongs to another service and is ignored here. A key that is absent, or
set to anything other than `true`, means the step runs. The key is read once per workflow run.
If it cannot be read at all, nothing is skipped and the step logs a warning — the same
behavior as before this config existed.

### From the agent's environment

An environment variable set on the agent **overrides the platform** for that step, in both
directions:

| Variable                  | Effect                                                                   |
|---------------------------|--------------------------------------------------------------------------|
| `CREATE_CODE_REPOSITORY`  | `false` skips; any other value runs the step even if the platform says skip. |
| `CREATE_ASSET_REPOSITORY` | `false` skips; any other value runs the step even if the platform says skip. |

Mind that the two are inverted: `CREATE_CODE_REPOSITORY=false` skips, while
`createCodeRepository: true` skips. Only the exact lowercase value `false` disables a step,
so `FALSE` reads as "run it".

Skipping a step is not an error: the hook still reports success, and the step that remains
enabled runs normally. Setting both to `false` leaves the application created with no
repositories provisioned.

---

## Extension points

Two steps ship doing nothing and exist to be replaced. Installing this repository unchanged behaves
exactly as it would without them, so adopting either one is opt-in.

| Step | Runs | For |
|---|---|---|
| `scripts/approve_creation` | Before any repository is created | Deciding whether this application may be created at all |
| `scripts/code-repo/scaffold_repository` | After the repository exists, before the first build | Whatever the template cannot express: metadata-dependent substitutions, CODEOWNERS, environments, rulesets, custom properties |

`scaffold_repository` sits directly under `scripts/code-repo` rather than under a provider
directory. A provider-scoped slot would need one copy of the no-op per provider and would break the
workflow for any provider that was missing it.

Both are **sourced** into the workflow's shared shell, so the usual rule applies: `return` to
continue, `exit 1` to stop the workflow, and never `exit 0` — that ends the shared shell and
silently skips every step that follows. Their stdout becomes the hook's messages, which is what the
developer sees in the console.

Each file documents the variables it can read; the headers are the reference.

### Refusing an operation

A step that refuses should not report a failure. The platform accepts `success`, `cancelled`,
`failed` and `recoverable_failure`, and `cancelled` is what a refusal is: the request was understood
and declined, not broken. `alm_cancel` records the reason and entrypoint closes the hook with it:

```bash
APPROVE_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$APPROVE_DIR/cancel"

alm_cancel "businessUnit 'Payments' requires an approver"
exit 1
```

The `exit 1` is what stops the workflow; `alm_cancel` only decides how the hook is reported. The
reason is prepended to the messages so it is not lost among the workflow's own log lines, and a
cancelled hook carries no `callback_body`.

### Budget

Both steps run while the application is held in `pending_hook` and the developer is watching the
console. Time spent here is time they wait, and a step that hangs blocks application creation for
the whole NRN — a `before` hook fails closed. Configuring environments and rulesets belongs here.
Publishing an SDK does not; that wants to be asynchronous.

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
