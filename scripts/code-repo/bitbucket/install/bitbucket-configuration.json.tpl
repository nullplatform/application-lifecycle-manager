{
  "name": "Bitbucket Cloud",
  "description": "Creates and configures application repositories in Bitbucket Cloud, including Pipelines and CI credentials",
  "slug": "bitbucket-configuration",
  "category": "code-repository",
  "icon": "simple-icons:bitbucket",
  "visible_to": [
    "{{ env.Getenv "NRN" }}"
  ],
  "allow_dimensions": false,
  "schema": {
    "type": "object",
    "required": ["setup"],
    "additionalProperties": false,
    "properties": {
      "setup": {
        "type": "object",
        "order": 1,
        "required": ["workspace", "project_key", "email"],
        "description": "Where nullplatform creates repositories, and which bot user it acts as.",
        "properties": {
          "workspace": {
            "type": "string",
            "title": "Workspace",
            "description": "The Bitbucket workspace slug new repositories are created in (e.g. acme). This is the segment after bitbucket.org/ in your repository URLs.",
            "order": 1
          },
          "project_key": {
            "type": "string",
            "title": "Project key",
            "description": "The key of the Bitbucket project new repositories are filed under (e.g. APP). Required: if it is omitted Bitbucket does not fail, it silently files the repository under the workspace's oldest project.",
            "order": 2
          },
          "email": {
            "type": "string",
            "format": "email",
            "title": "Bot user email",
            "description": "Atlassian account email of the dedicated Bitbucket bot user. It is the HTTP Basic username that pairs with the BITBUCKET_API_TOKEN environment variable — not a secret on its own.",
            "order": 3
          },
          "installation_url": {
            "type": "string",
            "format": "uri",
            "title": "Installation URL",
            "description": "Base URL of the Bitbucket web UI and git remotes. Only change this if you do not use bitbucket.org.",
            "order": 4,
            "default": "https://bitbucket.org"
          }
        }
      },
      "access": {
        "type": "object",
        "order": 2,
        "description": "Who is granted access to every repository nullplatform creates.",
        "properties": {
          "default_collaborators": {
            "type": "array",
            "title": "Default collaborators",
            "description": "Principals granted permission on each new repository. They must already be members of the workspace: Bitbucket has no API to invite one.",
            "order": 1,
            "default": [],
            "items": {
              "type": "object",
              "required": ["id", "role", "type"],
              "properties": {
                "type": {
                  "type": "string",
                  "title": "Type",
                  "description": "Whether this entry addresses a single user or a workspace group.",
                  "order": 1,
                  "default": "user",
                  "oneOf": [
                    { "const": "user",  "title": "User" },
                    { "const": "group", "title": "Group" }
                  ]
                },
                "id": {
                  "type": "string",
                  "title": "Identifier",
                  "description": "For a user: the Atlassian account ID (e.g. 712020:1a2b...), the Bitbucket UUID including braces, or the workspace nickname. Email addresses cannot be used — Bitbucket removed them from its API. For a group: the group slug.",
                  "order": 2
                },
                "role": {
                  "type": "string",
                  "title": "Permission",
                  "description": "The repository permission to grant.",
                  "order": 3,
                  "default": "write",
                  "oneOf": [
                    { "const": "read",  "title": "Read" },
                    { "const": "write", "title": "Write" },
                    { "const": "admin", "title": "Admin" }
                  ]
                }
              }
            }
          }
        }
      }
    },
    "uiSchema": {
      "type": "VerticalLayout",
      "elements": [
        {
          "type": "Control",
          "scope": "#/properties/setup/properties/workspace"
        },
        {
          "type": "Control",
          "scope": "#/properties/setup/properties/project_key"
        },
        {
          "type": "Control",
          "scope": "#/properties/setup/properties/email"
        },
        {
          "type": "Control",
          "scope": "#/properties/setup/properties/installation_url"
        },
        {
          "type": "Label",
          "text": "> **⚠️ The API token is NOT configured here — set it as an environment variable**\n\nThe bot user's Atlassian API token is a secret, and nullplatform nullifies secret attribute values on authenticated provider reads. A token stored in this configuration could therefore never be read back by the workflow that needs it, so it is deliberately not part of this form.\n\nSet it on the **Application Lifecycle Manager** deployment:\n\n- **`BITBUCKET_API_TOKEN`** *(required, sensitive)* — the bot user's Atlassian API token. It is the HTTP Basic password for the REST API and, with the git username `x-bitbucket-api-token-auth`, the password for git over HTTPS.\n\nThe token must belong to a Bitbucket user with **two-step verification (2SV) enabled**. That is the only principal Bitbucket permits to enable Pipelines: an OAuth app (2LO) is refused there with a permanent `403`, and a workspace access token — explicitly \"not tied to a user\" — fails the same check. This works on every Bitbucket plan; no Premium required. Note this is **Bitbucket** 2SV, not Atlassian-account 2FA.\n\nAtlassian API tokens expire after at most **365 days** — rotate before then. Bitbucket **app passwords are not supported** (Atlassian removed them on 2026-07-28).",
          "options": { "format": "markdown" }
        },
        {
          "type": "Label",
          "text": "> **ℹ️ Optional environment overrides**\n\nEvery field above can also be supplied — or overridden — through the environment of the Application Lifecycle Manager deployment. The environment always wins over this configuration, which is useful for a one-off migration without editing the provider.\n\n- `BITBUCKET_WORKSPACE` — overrides **Workspace**\n- `BITBUCKET_PROJECT_KEY` — overrides **Project key**\n- `BITBUCKET_EMAIL` — overrides **Bot user email**\n- `BITBUCKET_INSTALLATION_URL` — overrides **Installation URL**\n- `BITBUCKET_API_BASE` — REST API base URL, defaults to `https://api.bitbucket.org/2.0`. Bitbucket Cloud serves its API from a different host than the web UI, which is why this is separate from **Installation URL**.",
          "options": { "format": "markdown" }
        },
        {
          "type": "Control",
          "scope": "#/properties/access/properties/default_collaborators"
        },
        {
          "type": "Label",
          "text": "> **ℹ️ Collaborators must already be members of the workspace**\n\nThe bot user can grant repository permissions, but Bitbucket exposes **no API to invite someone to a workspace** — so nullplatform cannot add a non-member for you. If a collaborator listed above is not a workspace member, repository provisioning fails with an error naming them, and a workspace administrator has to invite them first at `<installation URL>/<workspace>/workspace/settings/members`.\n\nBitbucket permissions are **read**, **write** and **admin**. The bot user itself needs repository, pipeline and project admin on the workspace.",
          "options": { "format": "markdown" }
        }
      ]
    }
  }
}
