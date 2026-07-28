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
        "required": ["workspace", "project_key"],
        "description": "Where new repositories are created.",
        "properties": {
          "workspace": {
            "type": "string",
            "title": "Workspace",
            "description": "The Bitbucket workspace slug new repositories are created in. It's the segment right after bitbucket.org/ in your repository URLs.",
            "order": 1
          },
          "project_key": {
            "type": "string",
            "title": "Project key",
            "description": "The key of the Bitbucket project new repositories belong to, such as APP. It's required: when the key is missing Bitbucket doesn't fail, it quietly files the repository under the oldest project in the workspace.",
            "order": 2
          },
          "installation_url": {
            "type": "string",
            "format": "uri",
            "title": "Installation URL",
            "description": "Base URL of the Bitbucket web UI and git remotes. Keep the default unless you don't use bitbucket.org.",
            "order": 3,
            "default": "https://bitbucket.org"
          }
        }
      },
      "access": {
        "type": "object",
        "order": 2,
        "description": "Who gets access to the repositories that are created.",
        "properties": {
          "default_collaborators": {
            "type": "array",
            "title": "Default collaborators",
            "description": "Users and groups granted permission on every new repository. They need to be members of the workspace already, because Bitbucket has no API to invite someone.",
            "order": 1,
            "default": [],
            "items": {
              "type": "object",
              "required": ["id", "role", "type"],
              "properties": {
                "type": {
                  "type": "string",
                  "title": "Type",
                  "description": "Whether this entry is a single user or a workspace group.",
                  "order": 1,
                  "default": "user",
                  "enum": ["user", "group"]
                },
                "id": {
                  "type": "string",
                  "title": "Identifier",
                  "description": "For a user, the Atlassian account ID or the Bitbucket UUID including its braces. For a group, the group slug. Email addresses don't work here, Bitbucket removed them from its API.",
                  "order": 2
                },
                "role": {
                  "type": "string",
                  "title": "Permission",
                  "description": "The repository permission to grant.",
                  "order": 3,
                  "default": "write",
                  "enum": ["read", "write", "admin"]
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
          "scope": "#/properties/setup/properties/installation_url"
        },
        {
          "type": "Label",
          "text": "> **⚠️ Set two environment variables on your Application Lifecycle Manager deployment**\n\nThe credential isn't stored here:\n\n- **`BITBUCKET_EMAIL`** — the Atlassian account email of your Bitbucket bot user.\n- **`BITBUCKET_API_TOKEN`** — that user's Atlassian API token.\n\nThe bot user needs two-step verification enabled in Bitbucket, plus repository, pipeline and project admin permissions on the workspace.",
          "options": { "format": "markdown" }
        },
        {
          "type": "Control",
          "scope": "#/properties/access/properties/default_collaborators"
        }
      ]
    }
  }
}
