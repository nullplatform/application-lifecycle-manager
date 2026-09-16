variable "nrn" {
  description = "NRN the configuration is anchored to. The module strips any namespace segment, so an account-level NRN is what ends up stored."
  type        = string
}

variable "bitbucket_workspace" {
  description = "The Bitbucket workspace slug new repositories are created in."
  type        = string
}

variable "bitbucket_project_key" {
  description = "Key of the Bitbucket project new repositories are filed under. Required: omit it and Bitbucket silently files the repository under the workspace's oldest project."
  type        = string
}

variable "bitbucket_installation_url" {
  description = "Base URL of the Bitbucket web UI and git remotes."
  type        = string
  default     = "https://bitbucket.org"
}

variable "bitbucket_collaborators" {
  description = "Principals granted permission on every new repository. They must already be members of the workspace: Bitbucket has no API to invite one. `id` is an Atlassian account_id, a Bitbucket UUID with braces, or a workspace nickname — an email cannot be resolved."
  type = list(object({
    id   = string
    role = string
    type = string
  }))
  default = []

  validation {
    condition     = alltrue([for c in var.bitbucket_collaborators : contains(["read", "write", "admin"], c.role)])
    error_message = "Bitbucket repository permissions are read, write or admin."
  }

  validation {
    condition     = alltrue([for c in var.bitbucket_collaborators : contains(["user", "group"], c.type)])
    error_message = "A collaborator type is either user or group."
  }
}
