locals {
  ssm_path_key_pair                = "/${var.name}/pritunl_instance_private_key"
  ssm_path_default_credentials     = "/${var.name}/pritunl_default_credenstials"
  iam_role_default_name            = "${var.name}_pritunl_role"
  iam_instance_profile_defaut_name = "${var.name}_pritunl_instance_profile"
  cw_logs_default_name             = "/aws/${var.name}/pritunl_logs"

}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical account ID for Ubuntu AMIs
}

data "aws_iam_policy_document" "backups" {
  count = var.backups ? 1 : 0
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]
    effect    = "Allow"
    resources = ["${module.s3[0].s3_bucket_arn}/*"]
  }
}


resource "aws_iam_policy" "ssm_send_command_pritunl" {
  name        = "SSMSendCommandPritunlPolicy"
  description = "Policy to allow sending commands via SSM to the Pritunl instance"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ssm:SendCommand",
        Resource = [
          aws_instance.pritunl.arn,
          aws_ssm_document.restore_mongodb.arn
        ]
      },
    ],
  })
}


resource "aws_iam_policy_attachment" "ssm_send_command_attachment" {
  name       = "SSMSendCommandPolicyAttachment"
  policy_arn = aws_iam_policy.ssm_send_command_pritunl.arn
  roles      = [aws_iam_role.pritunl.name]
}


resource "aws_iam_role" "pritunl" {
  name = local.iam_role_default_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = var.tags

}

resource "aws_iam_policy" "backups" {
  count = var.backups ? 1 : 0

  policy = data.aws_iam_policy_document.backups[0].json
  tags   = var.tags
}


resource "aws_iam_instance_profile" "pritunl" {
  name = local.iam_instance_profile_defaut_name
  role = aws_iam_role.pritunl.name
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backups" {
  count = var.backups ? 1 : 0

  role       = aws_iam_role.pritunl.name
  policy_arn = aws_iam_policy.backups[0].arn

}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.pritunl.name

}

resource "aws_iam_policy" "additional_instance_role_policy" {
  count = var.additional_instance_role_policy_json != null ? 1 : 0

  policy = var.additional_instance_role_policy_json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "additional_instance_role_policy" {
  count = var.additional_instance_role_policy_json != null ? 1 : 0

  policy_arn = aws_iam_policy.additional_instance_role_policy[0].arn
  role       = aws_iam_role.pritunl.name
}

resource "aws_eip" "pritunl" {
  count    = var.eip_id == null ? 1 : 0
  instance = aws_instance.pritunl.id

  tags = var.tags
}

data "aws_eip" "pritunl" {
  count = var.eip_id != null ? 1 : 0
  id    = var.eip_id
}

resource "aws_eip_association" "pritunl" {
  count         = var.eip_id != null ? 1 : 0
  instance_id   = aws_instance.pritunl.id
  allocation_id = var.eip_id
}

resource "aws_instance" "pritunl" {

  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  availability_zone = data.aws_availability_zones.available.names[0]
  key_name          = var.create_ssh_key ? module.key_pair[0].key_pair_name : null

  vpc_security_group_ids = [aws_security_group.pritunl.id]
  subnet_id              = var.subnet_id
  monitoring             = var.monitoring
  user_data = templatefile("${path.module}/files/init.sh", {
    SSM_PATH_DEFAULT_CREDENTIAL = local.ssm_path_default_credentials,
    CLOUD_WATCH                 = var.cloudwatch_logs ? "true" : "false",
    CW_LOGS_GROUP               = coalesce(var.cloudwatch_logs_group_name, local.cw_logs_default_name)
    BACKUPS                     = var.backups ? "true" : "false",
    BUCKET_NAME                 = var.backups ? module.s3[0].s3_bucket_id : "",
    AWS_DEFAULT_REGION          = data.aws_region.current.name,
    AUTO_RESTORE                = var.auto_restore
    BACKUP_FILE                 = ""
    SSM_DOCUMENT_NAME           = aws_ssm_document.restore_mongodb.name
    ADDITIONAL_USER_DATA        = var.additional_user_data
  })
  iam_instance_profile = aws_iam_instance_profile.pritunl.name

  dynamic "root_block_device" {
    for_each = var.root_block_device
    content {
      volume_type           = root_block_device.value.volume_type
      throughput            = root_block_device.value.throughput
      volume_size           = root_block_device.value.volume_size
      encrypted             = root_block_device.value.encrypted
      kms_key_id            = root_block_device.value.kms_key_id != "" ? root_block_device.value.kms_key_id : null
      iops                  = root_block_device.value.iops
      delete_on_termination = root_block_device.value.delete_on_termination
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [ami]
  }
}

module "key_pair" {
  count = var.create_ssh_key ? 1 : 0

  source             = "terraform-aws-modules/key-pair/aws"
  version            = "2.0.0"
  key_name           = var.name
  create_private_key = true
  tags               = var.tags
}

resource "aws_ssm_parameter" "ec2_keypair" {
  count = var.create_ssh_key ? 1 : 0

  name        = local.ssm_path_key_pair
  description = "Stores the ssh private key of pritunl ec2 key pair"
  type        = "SecureString"
  value       = module.key_pair[0].private_key_pem
  tags        = var.tags

}

resource "aws_ssm_parameter" "default_credential" {
  name        = local.ssm_path_default_credentials
  description = "Stores started credential of pritunl service"
  type        = "SecureString"
  value       = " "
  lifecycle {
    ignore_changes = [value]
  }
  tags = var.tags
}

module "s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"
  count   = var.backups ? 1 : 0

  bucket = "${var.name}-backups-${data.aws_caller_identity.current.account_id}"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy           = var.s3_force_destroy

  lifecycle_rule = var.s3_lifecycle_rule

  versioning = {
    enabled = true
  }
  tags = var.tags
}

resource "aws_security_group" "pritunl" {
  name        = var.name
  description = "Security group for Pritunl"
  vpc_id      = var.vpc_id


  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = egress.value.description
    }
  }
  tags = var.tags
}




resource "aws_iam_policy" "cloudwatch_logs_policy" {
  count       = var.cloudwatch_logs ? 1 : 0
  name        = "CloudWatchLogsPolicy"
  description = "A policy that allows publishing logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:CreateLogGroup"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  count      = var.cloudwatch_logs ? 1 : 0
  role       = aws_iam_role.pritunl.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy[0].arn
}

resource "aws_cloudwatch_log_group" "pritunl_log_group" {
  count             = var.cloudwatch_logs ? 1 : 0
  name              = coalesce(var.cloudwatch_logs_group_name, local.cw_logs_default_name)
  retention_in_days = var.cloudwatch_logs_retention_in_days
  tags              = var.tags
}


resource "aws_iam_policy" "ssm_put_parameter" {
  name        = "SSMPutParameterPolicy"
  description = "Policy to allow put parameter in SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ssm:PutParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/*"
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "ssm_put_parameter_attachment" {
  name       = "SSMPutParameterPolicyAttachment"
  roles      = [aws_iam_role.pritunl.name]
  policy_arn = aws_iam_policy.ssm_put_parameter.arn

}



resource "aws_route53_record" "pritunl" {
  count   = var.create_route53_record ? 1 : 0
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [var.eip_id == null ? aws_eip.pritunl[0].public_ip : data.aws_eip.pritunl[0].public_ip]
}


resource "null_resource" "wait_for_installation_pritunl" {
  count = var.wait_for_installation ? 1 : 0

  triggers = {
    instance_id = aws_instance.pritunl.id
  }

  provisioner "local-exec" {
    command = <<EOT
sleep 60
success=false
while [[ $success == false ]]; do
  if command_id=$(aws ssm send-command --region "${data.aws_region.current.name}" --document-name ${aws_ssm_document.cloud_init_wait[0].name} --instance-ids "${aws_instance.pritunl.id}" --output text --query "Command.CommandId"); then
    if aws ssm wait command-executed --region "${data.aws_region.current.name}" --command-id "$command_id" --instance-id "${aws_instance.pritunl.id}"; then
      success=true
      echo "Pritunl successfully installed."
      break
    else
      echo "Pritunl install in progress"
    fi
    sleep 30
  fi
done
EOT
  }
}

resource "aws_ssm_document" "cloud_init_wait" {
  count = var.wait_for_installation ? 1 : 0

  name            = "${var.name}-cloud-init-wait"
  document_type   = "Command"
  document_format = "YAML"
  content         = <<-DOC
    schemaVersion: '2.2'
    description: Wait for cloud init to finish
    mainSteps:
    - action: aws:runShellScript
      name: WaitUserdata
      precondition:
        StringEquals:
        - platformType
        - Linux
      inputs:
        runCommand:
        - cloud-init status --wait
    DOC
  tags            = var.tags
}


resource "aws_ssm_document" "backups_sript" {
  count = var.backups ? 1 : 0

  name            = "${var.name}_backup_mongodb"
  document_type   = "Command"
  document_format = "JSON"
  content         = <<DOC
{
  "schemaVersion": "2.2",
  "description": "Configure crontab for MongoDB backups to S3",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "BackupMongoToS3",
      "inputs": {
        "runCommand": [
          "mongodump --gzip --archive=/tmp/mongodb_backup.gz",
          "aws s3 cp /tmp/mongodb_backup.gz s3://${var.name}-backups-${data.aws_caller_identity.current.account_id}/mongodb_backup.gz",
          "rm /tmp/mongodb_backup.gz"
        ]
      }
    }
  ]
}
DOC
  tags            = var.tags
}



resource "aws_ssm_association" "backup" {
  count = var.backups ? 1 : 0

  name                = aws_ssm_document.backups_sript[0].name
  schedule_expression = var.backups_cron

  targets {
    key    = "InstanceIds"
    values = [aws_instance.pritunl.id]
  }

}

resource "aws_ssm_document" "restore_mongodb" {
  name          = "restore-mongodb-backup"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Restore MongoDB from S3 backup",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "restoreBackup",
        inputs = {
          runCommand = [
            "echo 'Restoring from backup...'",
            "aws s3 cp s3://${var.name}-backups-${data.aws_caller_identity.current.account_id}/mongodb_backup.gz ./mongodb_backup.gz",
            "mongorestore --gzip --archive=mongodb_backup.gz",
            "rm mongodb_backup.gz"
          ]
        }
      }
    ]
  })
}

