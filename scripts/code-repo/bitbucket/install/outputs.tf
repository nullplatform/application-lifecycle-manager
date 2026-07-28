output "specification_id" {
  description = "ID of the bitbucket-configuration provider specification. This is the UUID that scripts/code-repo/create_code_repository maps `bitbucket` to."
  value       = module.bitbucket_spec.specification_id
}

output "slug" {
  description = "Slug of the specification, resolved from the rendered template (bitbucket-configuration)."
  value       = module.bitbucket_spec.slug
}
