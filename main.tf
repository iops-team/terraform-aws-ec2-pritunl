locals {
  ssm_path_key_pair                = "/${var.env}/${var.name}/pritunl_instance_private_key"
  ssm_path_default_credentials     = "/${var.env}/${var.name}/pritunl_default_credenstials"
  iam_role_default_name            = "${var.env}_${var.name}_pritunl_role"
  iam_policy_default_name          = "${var.env}_${var.name}"
  iam_instance_profile_defaut_name = "${var.env}_${var.name}_pritunl_instance_profile"
  cw_logs_default_name             = "/aws/${var.env}/${var.name}/pritunl_logs"
  ssm_document_default_name         = "${var.env}_${var.name}"
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

data "aws_iam_policy_document" "autorestore" {
  count = var.auto_restore ? 1 : 0

  statement {
    actions = [
      "s3:GetObject",
    ]
    effect = "Allow"
    resources = ["${module.s3[0].s3_bucket_arn}/*"]
  }

  statement {
    actions = [
      "ssm:SendCommand",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:document/${local.ssm_document_default_name}_restore_mongodb_db"
    ]
  }

  statement {
    actions = [
      "ssm:SendCommand",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }
}


resource "aws_iam_policy" "autorestore" {
  count      = var.auto_restore ? 1 : 0
  name        = "${local.iam_policy_default_name}_autorestore_policy"
  description = "Policy to allow backups and sending commands via SSM to the Pritunl instance"
  policy      = data.aws_iam_policy_document.autorestore[0].json
}

resource "aws_iam_policy_attachment" "autorestore" {
  count      = var.auto_restore ? 1 : 0
  name       = "${local.iam_instance_profile_defaut_name}_autorestore_policy_attachment"
  policy_arn = aws_iam_policy.autorestore[0].arn
  roles      = [aws_iam_role.pritunl.name]
}

resource "aws_iam_policy" "backups" {
  count = var.backups ? 1 : 0

  policy = data.aws_iam_policy_document.backups[0].json
  tags   = var.tags
}

data "aws_iam_policy_document" "backups" {
  count = var.backups ? 1 : 0
  statement {
    actions = [
      "s3:PutObject",
    ]
    effect    = "Allow"
    resources = ["${module.s3[0].s3_bucket_arn}/*"]       
  }
}

resource "aws_iam_role_policy_attachment" "backups" {
  count = var.backups ? 1 : 0

  role       = aws_iam_role.pritunl.name
  policy_arn = aws_iam_policy.backups[0].arn

}

resource "aws_iam_instance_profile" "pritunl" {
  name = local.iam_instance_profile_defaut_name
  role = aws_iam_role.pritunl.name
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.pritunl.name

}

resource "aws_cloudwatch_log_group" "pritunl_log_group" {
  count             = var.cloudwatch_logs ? 1 : 0
  name              = coalesce(var.cloudwatch_logs_group_name, local.cw_logs_default_name)
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  count       = var.cloudwatch_logs ? 1 : 0
  name        = "${local.iam_policy_default_name}_cloudwatch_logs_policy"
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

resource "aws_iam_policy" "ssm_put_parameter" {
  name        = "${local.iam_policy_default_name}_ssm_put_parametr_policy"
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
  name       = "${local.iam_policy_default_name}_ssm_put_parameter_attachment_policy"
  roles      = [aws_iam_role.pritunl.name]
  policy_arn = aws_iam_policy.ssm_put_parameter.arn

}

resource "aws_iam_policy" "AssociateEIP" {
  name   = "${local.iam_policy_default_name}_eip_associate_policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ec2:AssociateAddress",
        Resource = "*"
        }
    ]
  })
}

resource "aws_iam_policy_attachment" "attachEIP" {
  name       = "${local.iam_policy_default_name}_eip_attachment_policy"
  roles      = [aws_iam_role.pritunl.name]
  policy_arn = aws_iam_policy.AssociateEIP.arn

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

resource "aws_ssm_document" "cloud_init_wait" {
  count = var.wait_for_installation ? 1 : 0

  name            = "${local.ssm_document_default_name}_cloud_init_wait"
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

resource "aws_ssm_document" "backups_script" {
  count = var.backups ? 1 : 0

  name            = "${local.ssm_document_default_name}_backup_mongodb"
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
          "aws s3 cp /tmp/mongodb_backup.gz s3://${var.env}-${var.name}-backups-${data.aws_caller_identity.current.account_id}/mongodb_backup.gz",
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

  name                = aws_ssm_document.backups_script[0].name
  schedule_expression = var.backups_cron

  targets {
    key    = "tag:Name"
    values = ["${var.env}-${var.name}"]
  }

}

resource "aws_ssm_document" "restore_mongodb" {
  count = var.auto_restore ? 1 : 0

  name          = "${local.ssm_document_default_name}_restore_mongodb_db"
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
            "aws s3 cp s3://${var.env}-${var.name}-backups-${data.aws_caller_identity.current.account_id}/mongodb_backup.gz ./mongodb_backup.gz",
            "mongorestore --gzip --archive=mongodb_backup.gz",
            "rm ./mongodb_backup.gz",
            "PRITUNL_DEFAULT_CREDENTIALS=$(sudo pritunl default-password | grep -E 'username:|password:' | awk '{print $1,$2}')",
            "aws ssm put-parameter --region ${data.aws_region.current.name} --name ${local.ssm_path_default_credentials} --type 'SecureString' --value \"$PRITUNL_DEFAULT_CREDENTIALS\" --overwrite"
          ]
        }
      }
    ]
  })
}

module "s3" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"
  count   = var.backups || var.auto_restore ? 1 : 0

  bucket = "${var.env}-${var.name}-backups-${data.aws_caller_identity.current.account_id}"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle_rule = var.s3_lifecycle_rule

  versioning = {
    enabled = true
  }
  tags = var.tags
}

resource "aws_security_group" "pritunl" {
  name        = "${var.env}-${var.name}-security-group"
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

resource "aws_route53_record" "pritunl" {

  count   = var.create_route53_record ? 1 : 0
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_eip.pritunl.public_ip]

}

resource "aws_eip" "pritunl" {
  vpc = true
  tags = merge(
    var.tags,
    {
      "Name" = "${var.env}-${var.name}"
    }
  )
}

resource "aws_launch_template" "pritunl" {
  name_prefix   = "${var.env}-${var.name}-launch-template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.create_ssh_key ? module.key_pair[0].key_pair_name : null

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_block_device[0].volume_size
      volume_type           = var.root_block_device[0].volume_type
      delete_on_termination = var.root_block_device[0].delete_on_termination
      encrypted             = var.root_block_device[0].encrypted
      kms_key_id            = var.root_block_device[0].kms_key_id != "" ? var.root_block_device[0].kms_key_id : null
      throughput            = var.root_block_device[0].throughput
      iops                  = var.root_block_device[0].iops
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.pritunl.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.pritunl.name
  }

  user_data = base64encode(templatefile("${path.module}/files/init.sh", {
    SSM_PATH_DEFAULT_CREDENTIAL = local.ssm_path_default_credentials,
    CLOUD_WATCH                 = var.cloudwatch_logs ? "true" : "false",
    CW_LOGS_GROUP               = coalesce(var.cloudwatch_logs_group_name, local.cw_logs_default_name),
    BACKUPS                     = var.backups ? "true" : "false",
    BUCKET_NAME                 = var.backups ? module.s3[0].s3_bucket_id : "",
    AWS_DEFAULT_REGION          = data.aws_region.current.name,
    AUTO_RESTORE                = var.auto_restore
    BACKUP_FILE                 = ""
    SSM_DOCUMENT_NAME           = aws_ssm_document.restore_mongodb[0].name
    EIP_ID                      = aws_eip.pritunl.id

  }))

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "pritunl" {

  launch_template {
    id      = aws_launch_template.pritunl.id
    version = "$Latest"
  }

  min_size         = 1
  max_size         = 1
  desired_capacity = 1
  vpc_zone_identifier = [var.subnet_id]

  tag {
    key                 = "Name"
    value               = "${var.env}-${var.name}"
    propagate_at_launch = true    
  }
  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "null_resource" "wait_for_installation_pritunl" {
  count = var.wait_for_installation ? 1 : 0
  triggers = {
    autoscaling_group_name = aws_autoscaling_group.pritunl.name
  }

  provisioner "local-exec" {
    command = <<EOT
sleep 60
instance_ids=$(aws autoscaling describe-auto-scaling-groups --region "${data.aws_region.current.name}" --auto-scaling-group-names "${aws_autoscaling_group.pritunl.name}" --query "AutoScalingGroups[0].Instances[*].InstanceId" --output text)
success=false
while [[ $success == false ]]; do
  if command_id=$(aws ssm send-command --region "${data.aws_region.current.name}" --document-name ${aws_ssm_document.cloud_init_wait[0].name} --instance-ids $instance_ids --output text --query "Command.CommandId"); then
    if aws ssm wait command-executed --region "${data.aws_region.current.name}" --command-id "$command_id" --instance-id $instance_ids; then
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
