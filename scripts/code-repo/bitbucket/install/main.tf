# Creates the Bitbucket code-repository CONFIGURATION for an account: the record
# ALM reads with `np provider list` to learn which workspace and project new
# repositories go into.
#
# This is not the specification. That one is global, seeded by main-providers-api
# (slug `bitbucket`, id ca7019c5-f7da-4b79-8fd6-28afbaea366b), so nobody has to
# install it.
#
# The bot user's credentials are deliberately absent here: the specification
# declares no credential fields, because nullplatform nullifies secret attribute
# values on authenticated provider reads. Set BITBUCKET_EMAIL and
# BITBUCKET_API_TOKEN on the ALM deployment instead. See terraform.tfvars.example.

module "code_repository" {
  # TODO: move to the released tag (v6.8.1 or later) once
  # nullplatform/tofu-modules#463 is merged. Until then this points at that PR's
  # branch, because the version currently tagged sends a `type` that no longer
  # resolves to a specification, plus credential fields the API strips.
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/code_repository?ref=fix/code-repository-bitbucket-schema"

  git_provider = "bitbucket"
  nrn          = var.nrn
  dimensions   = var.dimensions

  bitbucket_workspace        = var.bitbucket_workspace
  bitbucket_project_key      = var.bitbucket_project_key
  bitbucket_installation_url = var.bitbucket_installation_url
  bitbucket_collaborators    = var.bitbucket_collaborators
}
