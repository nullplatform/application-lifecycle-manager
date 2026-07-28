# Creates the `bitbucket-configuration` provider specification (category
# code-repository) from bitbucket-configuration.json.tpl.
#
# Only the definition module is needed here. The configuration instances are
# created by the customer in the nullplatform UI (or with the nullplatform
# provider directly), and there is no agent involved -- the Application
# Lifecycle Manager reads the configuration itself -- so no api_key,
# configuration or notification_channel modules.
#
# NOTE: the module fetches the template over HTTP from
# "${var.repository_spec}/${var.repository_spec_branch}/${var.template_path}",
# not from local disk -- so the branch holding the template must be pushed
# before `tofu apply`.

module "bitbucket_spec" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/parameter_storage_definition?ref=v6.6.0"

  nrn                                      = var.nrn
  np_api_key                               = var.np_api_key
  extra_visible_to_nrns                    = var.extra_visible_to_nrns
  template_path                            = var.template_path
  repository_parameter_storage_spec        = var.repository_spec
  repository_parameter_storage_spec_branch = var.repository_spec_branch
}
