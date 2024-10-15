variable "name" {
  description = "The name of the resources."
  type        = string
}

variable "create_ssh_key" {
  description = "Flag to determine if an SSH key should be created."
  type        = bool
  default     = true
}

variable "backups" {
  description = "Flag to determine if an S3 bucket should be created."
  type        = bool

}

variable "instance_type" {
  description = "The instance type of the EC2 instance."
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = null
}

variable "vpc_id" {
  description = "The VPC ID where the security group and EC2 instance will be created."
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where the EC2 instance will be launched."
  type        = string
}



variable "monitoring" {
  description = "Whether to enable detailed monitoring for the Pritunl instance"
  type        = bool
  default     = false
}


variable "cloudwatch_logs" {
  description = "A flag to enable or disable log streaming to CloudWatch"
  type        = bool
  default     = false
}


variable "backups_cron" {
  description = "Cron schedule for MongoDB backups"
  type        = string
  default     = "cron(0 0 * * ? *)"

}

variable "wait_for_installation" {
  description = "Whether to wait for the completion of the init.sh script on the EC2 instance"
  type        = bool
  default     = true
}

variable "cloudwatch_logs_group_name" {
  description = "The name of the CloudWatch Logs Group for Pritunl logs"
  type        = string
  default     = null
}

variable "create_route53_record" {
  description = "Whether to create Route53 record"
  type        = bool
  default     = false
}

variable "zone_id" {
  description = "The Route53 zone ID where the record will be created"
  type        = string
  default     = null
}

variable "domain_name" {
  description = "The domain name for the Route53 record"
  type        = string
  default     = null
}

variable "root_block_device" {
  description = "Configuration for the root block device"
  type = list(object({
    volume_type           = string
    throughput            = number
    volume_size           = number
    encrypted             = bool
    kms_key_id            = string
    iops                  = number
    delete_on_termination = bool
  }))
  default = [{
    volume_type           = "gp3"
    throughput            = 200
    volume_size           = 30
    encrypted             = true
    kms_key_id            = ""
    iops                  = 0
    delete_on_termination = true
  }]
}

variable "ingress_rules" {
  description = "Default ingress rules for the security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access"
    }
  ]
}


variable "egress_rules" {
  description = "Default egress rules for the security group"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow all outbound traffic"
    }
  ]
}
variable "s3_lifecycle_rule" {
  description = "Lifecycle rule for the S3 bucket"
  type = list(object({
    id                                     = string
    enabled                                = bool
    abort_incomplete_multipart_upload_days = number
    expiration = object({
      days                         = number
      expired_object_delete_marker = bool
    })
    noncurrent_version_expiration = list(object({
      noncurrent_days = number
    }))
  }))
  default = [
    {
      id                                     = "removeOldVersions"
      enabled                                = true
      abort_incomplete_multipart_upload_days = 1
      expiration = {
        days                         = 0
        expired_object_delete_marker = true
      }
      noncurrent_version_expiration = [
        {
          noncurrent_days = 14
        }
      ]
    }
  ]
}

variable "auto_restore" {
  description = "Try to restore from the backup if it exists, if the backup does not exist, a new user will be created"
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention_in_days" {
  description = "Retention in days to configure for the CloudWatch log group"
  type        = number
  default     = 30
}

variable "s3_force_destroy" {
  description = "Enables Terraform to forcibly destroy the bucket with backups, permanently deleting its contents"
  type        = bool
  default     = false
}

variable "additional_user_data" {
  description = "Additional user data script to execute after Pritunl has started."
  type        = string
  default     = ""
}

variable "additional_instance_role_policy_json" {
  description = "Additional JSON formatted IAM policy to attach to the Pritunl EC2 instance role."
  type        = string
  default     = null
}

variable "eip_id" {
  description = "The allocation ID of an existing Elastic IP to associate with the Pritunl instance. If unset, will create a new Elastic IP."
  type        = string
  default     = null
}

