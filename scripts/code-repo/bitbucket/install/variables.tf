variable "nrn" {
  description = "NRN the provider specification is anchored to (and the first NRN it is visible to)."
  type        = string
}

variable "np_api_key" {
  description = "nullplatform API key. Passed through for interface consistency; the nullplatform provider itself authenticates from the environment (NULLPLATFORM_API_KEY)."
  type        = string
  sensitive   = true
}

variable "extra_visible_to_nrns" {
  description = "Additional NRNs the specification should be visible to besides var.nrn. Use organization=* to publish it globally."
  type        = list(string)
  default     = []
}

variable "template_path" {
  description = "Path of the specification template, relative to the served repository root."
  type        = string
  default     = "scripts/code-repo/bitbucket/install/bitbucket-configuration.json.tpl"
}

variable "repository_spec" {
  description = "Base URL the template is fetched from. Defaults to this repository on GitHub; point it at a local HTTP server to install an uncommitted template (see terraform.tfvars.example)."
  type        = string
  default     = "https://raw.githubusercontent.com/nullplatform/application-lifecycle-manager/refs/heads"
}

variable "repository_spec_branch" {
  description = "Branch segment appended to var.repository_spec."
  type        = string
  default     = "main"
}
