provider "aws" {
  version = ">= 2.28.1"
  region  = var.region
}

provider "random" {
  version = "~> 2.1"
}

data "aws_availability_zone" "az" {
  name = "${var.region}a"
}

data "aws_caller_identity" "current" {}

resource "random_id" "default" {
  byte_length = 8
}

resource "aws_iam_role_policy" "ds_policy" {
  name   = "ds-policy-${random_id.default.hex}"
  role   = aws_iam_role.ds_role.id
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:AttachVolume",
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:DescribeKeyPairs",
        "ec2:CreateTags"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_iam_role" "ds_role" {
  name               = "ds-role-${random_id.default.hex}"
  path               = "/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_instance_profile" "ds_instance_profile" {
  name = "ds-instance-profile-${random_id.default.hex}"
  path = "/"
  role = aws_iam_role.ds_role.id
}

resource "aws_security_group" "ds_runner_security_group" {
  name        = "ds-runner-sg-${random_id.default.hex}"
  description = "SG for Hub and Runner EC2 Instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr]
  }

  ingress {
    from_port   = 2376
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ds_hub_security_group" {
  name        = "ds-hub-sg-${random_id.default.hex}"
  description = "SG for Hub and Runner EC2 Instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.hub_ingress_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_access_cidr]
  }

  ingress {
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = [var.hub_ingress_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.hub_ingress_cidr]
  }

  ingress {
    from_port   = 32607
    to_port     = 32607
    protocol    = "tcp"
    cidr_blocks = [var.hub_ingress_cidr]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "ds_elb" {
  name            = "ds-elb-${random_id.default.hex}"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.ds_hub_security_group.id]
  # instances                   = ["i-0d5cf73e8ff7c0ba9"]
  cross_zone_load_balancing   = false
  idle_timeout                = 60
  connection_draining         = false
  connection_draining_timeout = 300
  internal                    = false

  listener {
    instance_port      = 8800
    instance_protocol  = "tcp"
    lb_port            = 8800
    lb_protocol        = "tcp"
    ssl_certificate_id = ""
  }

  listener {
    instance_port      = 443
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "tcp"
    ssl_certificate_id = ""
  }

  listener {
    instance_port      = 32607
    instance_protocol  = "tcp"
    lb_port            = 32607
    lb_protocol        = "tcp"
    ssl_certificate_id = ""
  }

  listener {
    instance_port      = 80
    instance_protocol  = "tcp"
    lb_port            = 80
    lb_protocol        = "tcp"
    ssl_certificate_id = ""
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    target              = "HTTP:80/"
    timeout             = 5
  }

  depends_on = [
    aws_security_group.ds_hub_security_group
  ]
}

resource "aws_ebs_volume" "ds_hub_volume" {
  availability_zone = data.aws_availability_zone.az.name
  size              = var.hub_volume_size
  type              = "gp2"

  tags = {
    Name = "ds-hub-volume-${random_id.default.hex}"
  }
}

resource "aws_launch_configuration" "ds_hub_launch_config" {
  name_prefix                 = "ds-hub"
  image_id                    = var.amis[var.region].Hub
  instance_type               = var.hub_instance_type
  iam_instance_profile        = aws_iam_instance_profile.ds_instance_profile.id
  key_name                    = var.key_name
  security_groups             = [aws_security_group.ds_hub_security_group.id]
  associate_public_ip_address = true
  enable_monitoring           = true
  ebs_optimized               = false
  placement_tenancy           = "default"
  depends_on = [aws_security_group.ds_hub_security_group,
    aws_ebs_volume.ds_hub_volume,
    aws_elb.ds_elb, aws_kms_key.ds_kms_key,
    aws_security_group.ds_runner_security_group]
  # TODO: user_data = "${file("userdata.sh")}"
  user_data = <<-EOF
              #! /bin/bash
              echo "Dotscience hub"
              INSTANCE_ID=$( curl -s http://169.254.169.254/latest/meta-data/instance-id )
              echo "Attaching volume ${aws_ebs_volume.ds_hub_volume.id} to $INSTANCE_ID"
              while ! aws ec2 attach-volume --volume-id "${aws_ebs_volume.ds_hub_volume.id}" --instance-id $INSTANCE_ID --region "${var.region}" --device /dev/sdf 
              do
                  echo "Waiting for volume to attach..."
                  sleep 5
              done
              echo "Waiting for mount device to show up"
              sleep 60
              echo "Starting Dotscience hub"  
              /home/ubuntu/startup.sh "${var.admin_password}" "${var.hub_volume_size}" /dev/nvme1n1 "${aws_elb.ds_elb.dns_name}" "${aws_kms_key.ds_kms_key.id}" "${var.region}" "${var.key_name}" "${aws_security_group.ds_runner_security_group.id}" "${module.vpc.public_subnets[0]}" "${var.amis[var.region].CPURunner}" "${var.amis[var.region].GPURunner}" "http://${kubernetes_service.grafana_lb.load_balancer_ingress[0].hostname}" "${var.grafana_admin_user}" "${var.grafana_admin_password}" 
              EOF

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 128
    delete_on_termination = true
  }
}

resource "aws_autoscaling_group" "ds_asg" {
  desired_capacity          = 1
  health_check_type         = "ELB"
  health_check_grace_period = 300
  min_elb_capacity          = 1
  launch_configuration      = aws_launch_configuration.ds_hub_launch_config.id
  max_size                  = 1
  min_size                  = 1
  name                      = "ds-asg-${random_id.default.hex}"
  vpc_zone_identifier       = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = var.project
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "ds_elb_asg" {
  autoscaling_group_name = aws_autoscaling_group.ds_asg.id
  elb                    = aws_elb.ds_elb.id
}

resource "aws_kms_key" "ds_kms_key" {
  description         = "Master key for protecting sensitive data"
  key_usage           = "ENCRYPT_DECRYPT"
  is_enabled          = true
  enable_key_rotation = false

  policy = <<POLICY
{
  "Version" : "2012-10-17",
  "Id" : "key-default-1",
  "Statement" : [ {
    "Sid" : "Enable IAM User Permissions",
    "Effect" : "Allow",
    "Principal" : {
      "AWS" : [ "${data.aws_caller_identity.current.arn}", "${aws_iam_role.ds_role.arn}" ]
    },
    "Action" : "kms:*",
    "Resource" : "*"
  } ]
}
POLICY
}

output "DotscienceHub_URL" {
  value = "http://${aws_elb.ds_elb.dns_name}"
}
