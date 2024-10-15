output "iam_role_name" {
  description = "The name of the IAM role created for Pritunl."
  value       = aws_iam_role.pritunl.name
}

output "iam_instance_profile_name" {
  description = "The name of the IAM instance profile associated with the Pritunl instance."
  value       = aws_iam_instance_profile.pritunl.name
}

output "instance_id" {
  description = "The ID of the Pritunl EC2 instance."
  value       = aws_instance.pritunl.id
}

output "eip_public_ip" {
  description = "The Elastic IP address associated with the Pritunl instance."
  value       = var.create_eip ? aws_eip.pritunl[0].public_ip : (var.eip_id != null ? data.aws_eip.pritunl[0].public_ip : null)
}

output "security_group_id" {
  description = "The ID of the security group created for Pritunl."
  value       = aws_security_group.pritunl.id
}

output "ssm_parameter_default_credential" {
  description = "The name of the SSM parameter storing the default credentials of the Pritunl service."
  value       = aws_ssm_parameter.default_credential.name
}

output "s3_bucket_id" {
  description = "The ID of the S3 bucket used for backups."
  value       = try(module.s3[0].s3_bucket_id, null)
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket used for backups."
  value       = try(module.s3[0].s3_bucket_arn, null)
}
output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Logs group for Pritunl logs."
  value       = try(aws_cloudwatch_log_group.pritunl_log_group[0].name, null)
}

output "route53_fqdn" {
  description = "The DNS name for the Pritunl instance."
  value       = try(aws_route53_record.pritunl[0].fqdn, null)
}

output "ssm_parameter_key_pair" {
  description = "The name of the SSM parameter storing the SSH private key of the Pritunl instance."
  value       = try(aws_ssm_parameter.ec2_keypair[0].name, null)
}
