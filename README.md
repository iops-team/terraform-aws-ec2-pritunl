## AWS EC2 Pritunl Module

This Terraform module is designed to deploy a Pritunl VPN server on AWS. It automates the creation of necessary resources including an EC2 instance with Ubuntu, Elastic IP, required IAM roles and policies for access management, an S3 bucket for backups, CloudWatch Logs for logging, and configures security through Security Groups.

#### Features

- **EC2 Instance**: Automatically creates an EC2 instance using a specified Ubuntu AMI.
- **IAM Roles and Policies**: Creates IAM roles and policies for managing access to AWS resources.
- **S3 Bucket**: Optionally creates an S3 bucket for storing backups.
- **CloudWatch Logs**: Optionally configures CloudWatch Logs for server logging.
- **Security Groups**: Configures inbound and outbound rules via Security Groups.
- **Elastic IP**: Associates an Elastic IP with the EC2 instance.
- **SSH Key Pair**: Optionally creates an SSH key for access to the EC2 instance.
- **Route53 Record**: Optionally creates a DNS record in Route53 for the EC2 instance.
- **SSM Parameters**: Stores configuration data in SSM Parameter Store.

#### Requirements

- Terraform >= 0.12
- AWS provider

#### Usage

To use this module, add the following code to your `main.tf` file, replacing parameters with your own values:

```hcl
module "pritunl" {
  source = "iops-team/ec2-pritunl/aws"

  name                       = "example-pritunl"
  create_ssh_key             = true
  backups                    = true
  backups_cron               = "cron(0 0 * * ? *)"
  instance_type              = "t3.micro"
  vpc_id                     = "vpc-0d7be8904638ef5fb"
  subnet_id                  = "subnet-06442a69eb3006b2e"
  monitoring                 = true
  cloudwatch_logs            = true
  wait_for_installation      = true
  create_route53_record      = true
  zone_id                    = "Z069875012GQNG6IN9LUI"
  domain_name                = "vpn.example.com"

  tags = {
    Environment = "production"
    Project     = "Pritunl VPN"
  }

  ingress_rules = [
    {
      from_port   = 80,
      to_port     = 80,
      protocol    = "tcp",
      cidr_blocks = ["0.0.0.0/0"],
      description = "HTTP access"
    },
    {
      from_port   = 443,
      to_port     = 443,
      protocol    = "tcp",
      cidr_blocks = ["0.0.0.0/0"],
      description = "HTTPS access"
    },
    {
      from_port   = 1194,
      to_port     = 1194,
      protocol    = "udp",
      cidr_blocks = ["0.0.0.0/0"],
      description = "VPN access"
    }
  ]

  egress_rules = [
    {
      from_port   = 0,
      to_port     = 0,
      protocol    = "-1",
      cidr_blocks = ["0.0.0.0/0"],
      description = "Allow all outbound traffic"
    }
  ]

  root_block_device = [
    {
      volume_type           = "gp3",
      throughput            = 125,
      volume_size           = 20,
      encrypted             = true,
      kms_key_id            = "",
      iops                  = 3000,
      delete_on_termination = true
    }
  ]

  s3_lifecycle_rule = [
    {
      id                                     = "expireBackups",
      enabled                                = true,
      abort_incomplete_multipart_upload_days = 7,
      expiration = {
        days                         = 30,
        expired_object_delete_marker = false
      },
      noncurrent_version_expiration = [
        {
          noncurrent_days = 60
        }
      ]
    }
  ]
}
```

Refer to the "Parameters" section for a full list of input variables.

#### Parameters
Incorporating all possible values for each variable in a module as complex as the one for deploying a Pritunl VPN server on AWS is a bit challenging due to the dynamic nature of AWS resources and Terraform configurations. However, I can enhance the table with more details, especially for variables with a predefined set of acceptable values, like instance types or boolean flags. Note that for many variables, such as IDs and names, the "possible values" are dependent on your AWS account resources and naming conventions.

| Name                              | Description                                                    | Type          | Possible Values                                                                                   | Default Value                                                                                                                                                                                                                                                                                                                                                                    | Required |
|-----------------------------------|----------------------------------------------------------------|---------------|----------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `name`                            | The resource name prefix                                       | `string`      | Any valid string                                                                                   | n/a                                                                                                                                                                                                                                                                                                                                                                                | Yes      |
| `create_ssh_key`                  | Flag to create an SSH key                                      | `bool`        | `true`, `false`                                                                                    | `true`                                                                                                                                                                                                                                                                                                                                                                             | No       |
| `backups`                         | Flag to create an S3 bucket for backups                        | `bool`        | `true`, `false`                                                                                    | `false`                                                                                                                                                                                                                                                                                                                                                                            | No       |
| `instance_type`                   | EC2 instance type                                              | `string`      | Any valid EC2 instance type (e.g., `t2.micro`, `t3.medium`)                                        | `"t2.micro"`                                                                                                                                                                                                                                                                                                                                                                       | No       |
| `vpc_id`                          | VPC ID for resource deployment                                 | `string`      | Any valid VPC ID                                                                                   | n/a                                                                                                                                                                                                                                                                                                                                                                                | Yes      |
| `subnet_id`                       | Subnet ID for EC2 deployment                                   | `string`      | Any valid subnet ID                                                                                | n/a                                                                                                                                                                                                                                                                                                                                                                                | Yes      |
| `monitoring`                      | Enable detailed monitoring                                     | `bool`        | `true`, `false`                                                                                    | `false`                                                                                                                                                                                                                                                                                                                                                                            | No       |
| `cloudwatch_logs`                 | Enable CloudWatch log streaming                                | `bool`        | `true`, `false`                                                                                    | `false`                                                                                                                                                                                                                                                                                                                                                                            | No       |
| `backups_cron`                    | Cron schedule for backups                                      | `string`      | Any valid cron schedule                                                                            | `"0 3 * * *"`                                                                                                                                                                                                                                                                                                                                                                      | No       |
| `cloudwatch_logs_group_name`      | CloudWatch Logs group name                                     | `string`      | Any valid string                                                                                   | `null`                                                                                                                                                                                                                                                                                                                                                                             | No       |
| `create_route53_record`           | Flag to create a Route53 DNS record                            | `bool`        | `true`, `false`                                                                                    | `false`                                                                                                                                                                                                                                                                                                                                                                            | No       |
| `zone_id`                         | Route53 zone ID                                                | `string`      | Any valid Route53 zone ID                                                                          | `null`                                                                                                                                                                                                                                                                                                                                                                             | No       |
| `domain_name`                     | Domain name for the Route53 record                             | `string`      | Any valid domain name                                                                              | `null`                                                                                                                                                                                                                                                                                                                                                                             | No       |
| `root_block_device`               | Configuration for the root block device                        | `list(object)`| Objects containing `volume_type`, `volume_size`, `iops`, etc.                                      | `[{"volume_type": "gp3", "throughput": 200, "volume_size": 30, "encrypted": true, "kms_key_id": "", "iops": 0, "delete_on_termination": true}]`                                                                                                                                                                                                                                    | No       |
| `ingress_rules`                   | Ingress rules for the security group                           | `list(object)`| Objects containing `from_port`, `to_port`, `protocol`, `cidr_blocks`                               | `[{"from_port": 80, "to_port": 80, "protocol": "tcp", "cidr_blocks": ["0.0.0.0/0"], "description": "HTTP access"}, {"from_port": 443, "to_port": 443, "protocol": "tcp", "cidr_blocks": ["0.0.0.0/0"], "description": "HTTPS access"}]`                                                                                                                                            | No       |
| `egress_rules`                    | Egress rules for the security group                            | `list(object)`| Objects containing `from_port`, `to_port`, `protocol`, `cidr_blocks`                               | `[{"from_port": 0, "to_port": 0, "protocol": "-1", "cidr_blocks": ["0.0.0.0/0"], "description": "Allow all outbound traffic"}]`                                                                                                                                                                                                                                                     | No       |
| `s3_lifecycle_rule`               | Lifecycle rule for the S3 bucket                               | `list(object)`| Objects defining S3 bucket lifecycle rules                                                        | `[{"id": "expireBackups", "enabled": true, "abort_incomplete_multipart_upload_days": 7, "expiration": {"days": 30, "expired_object_delete_marker": false}, "noncurrent_version_expiration": [{"noncurrent_days": 60}]}]`                                                                                                                                                           | No       |
| `auto_restore` | Try to restore from the backup if it exists, if the backup does not exist, a new user will be created | `bool` | `true`, `false` | `true` | No |


### Notes on Possible Values

- **Instance Type**: The instance type can be any that AWS supports. Common types include `t2.micro`, `t3.medium`, `m5.large`, but this is subject to AWS's current offerings.
- **Boolean Flags**: For `bool` type variables, `true` enables and `false` disables the feature or resource creation.
- **IDs and Names**: Values for IDs (`vpc_id`, `subnet_id`, `zone_id`) and names (`name`, `domain_name`, `cloudwatch_logs_group_name`) depend on the resources you have available in your AWS account and the naming conventions you wish to follow.
- **Cron Schedule**: The `backups_cron` follows the standard cron format. You can customize this schedule to your backup frequency requirements.

This table aims to provide clarity on the input variables, ensuring users can tailor the module to fit their specific AWS infrastructure and security needs.

#### Outputs

| Name                        | Description                       |
|-----------------------------|-----------------------------------|
| `instance_id`               | The ID of the created EC2 instance |
| `instance_public_ip`        | The public IP address of the EC2 instance |
| `security_group_id`         | The ID of the Security Group      |
| `iam_role_name`             | The name of the IAM role          |
| `s3_bucket_name`            | The name of the S3 bucket (if created) |

#### Modules
- [terraform-aws-modules/key-pair/aws](https://registry.terraform.io/modules/terraform-aws-modules/key-pair/aws)
- [terraform-aws-modules/s3-bucket/aws](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws)

#### Resources

- `aws_instance`
- `aws_iam_role`
- `aws_iam_policy`
- `aws_iam_instance_profile`
- `aws_iam_role_policy_attachment`
- `aws_ssm_parameter`
- `aws_security_group`
- `aws_eip`
- `aws_cloudwatch_log_group`
- `aws_s3_bucket` (optional)
- `aws_route53_record` (optional)

## License

This module is released under the [MIT License](https://opensource.org/licenses/MIT).