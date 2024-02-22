output "iam_role_name" {
  description = "The name of the IAM role created for Pritunl."
  value       = module.pritunl.iam_role_name
}

output "iam_instance_profile_name" {
  description = "The name of the IAM instance profile associated with the Pritunl instance."
  value       = module.pritunl.iam_instance_profile_name
}

output "instance_id" {
  description = "The ID of the Pritunl EC2 instance."
  value       = module.pritunl.instance_id
}

output "eip_public_ip" {
  description = "The Elastic IP address associated with the Pritunl instance."
  value       = module.pritunl.eip_public_ip
}

output "security_group_id" {
  description = "The ID of the security group created for Pritunl."
  value       = module.pritunl.security_group_id
}

output "ssm_parameter_default_credential" {
  description = "The name of the SSM parameter storing the default credentials of the Pritunl service."
  value       = module.pritunl.ssm_parameter_default_credential
}

output "s3_bucket_id" {
  description = "The ID of the S3 bucket used for backups."
  value       = module.pritunl.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket used for backups."
  value       = module.pritunl.s3_bucket_arn
}
output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Logs group for Pritunl logs."
  value       = module.pritunl.cloudwatch_log_group_name
}

output "route53_fqdn" {
  description = "The DNS name for the Pritunl instance."
  value       = module.pritunl.route53_fqdn
}

output "ssm_parameter_key_pair" {
  description = "The name of the SSM parameter storing the SSH private key of the Pritunl instance."
  value       = module.pritunl.ssm_parameter_key_pair
}
