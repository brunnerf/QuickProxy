data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "proxy" {
  # checkov:skip=CKV_AWS_8: EBS encryption handled via default account encryption; no sensitive data on root volume
  # checkov:skip=CKV2_AWS_41: IAM role attached via instance profile (ec2_ssm)
  # checkov:skip=CKV_AWS_88: Public IP required — this instance IS the SOCKS proxy exit point
  # checkov:skip=CKV_AWS_126: Detailed monitoring not enabled; free-tier project, cost outweighs benefit
  # checkov:skip=CKV_AWS_135: EBS optimisation not available on t3.micro
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.proxy_public.id
  vpc_security_group_ids      = [aws_security_group.proxy_sg.id]
  iam_instance_profile        = data.aws_iam_instance_profile.ec2_ssm.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    # 8 GB is sufficient for AL2; gp3 is cheaper than the gp2 AMI default
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/user-data.sh.tpl", {
    additional_public_keys = var.additional_public_keys
  })

  tags = merge(local.common_tags, { Name = "proxy-ec2" })

  lifecycle {
    ignore_changes = [
      ami,                        # prevent replacement when AWS publishes a newer Amazon Linux 2 AMI
      associate_public_ip_address, # AWS sets this to false when instance is stopped; ignore to prevent replacement on next apply
    ]
  }
}
