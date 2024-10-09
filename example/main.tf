module "pritunl" {
  source = "../"

  name                       = "example-pritunl"
  env                        = "prod"
  create_ssh_key             = true
  backups                    = true
  auto_restore               = true
  instance_type              = "t3.micro"
  vpc_id                     = "vpc-0d7be8904638ef5fb"
  subnet_id                  = "subnet-06442a69eb3006b2e"
  monitoring                 = true
  cloudwatch_logs            = true
  wait_for_installation      = true
  create_route53_record      = true
  zone_id                    = "Z069875012GQNG6IN9LUI"
  domain_name                = "vpn.example.com"
  backups_cron               = "cron(0 * * * ? *)"
  cloudwatch_logs_group_name = "example-pritunl-logs"

  tags = {
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
      from_port   = "1194",
      to_port     = "1200",
      protocol    = "tcp",
      cidr_blocks = ["0.0.0.0/0"],
      description = "VPN access"
    },
    {
      from_port   = "1194",
      to_port     = "1200",
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
