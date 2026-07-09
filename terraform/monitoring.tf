# ============================================================
# سيرفر المراقبة - بيشغل Prometheus + Alertmanager + Ansible
# ويتحكم في الـ EC2 instances الحقيقية عن طريق SSH
# ============================================================

# ---------------------------------------------------------
# Security Group الخاصة بسيرفر المراقبة
# ---------------------------------------------------------
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-monitoring-sg"
  description = "Allow access to monitoring dashboards and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Alertmanager UI"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-monitoring-sg"
  }
}

# ---------------------------------------------------------
# صلاحية IAM تسمح لسيرفر المراقبة يشوف قائمة الـ EC2 instances
# (مطلوبة لـ Prometheus Service Discovery و Ansible Dynamic Inventory)
# ---------------------------------------------------------
resource "aws_iam_role" "monitoring_role" {
  name = "${var.project_name}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "monitoring_describe_ec2" {
  name = "${var.project_name}-describe-ec2"
  role = aws_iam_role.monitoring_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "monitoring_profile" {
  name = "${var.project_name}-monitoring-profile"
  role = aws_iam_role.monitoring_role.name
}

# ---------------------------------------------------------
# سيرفر المراقبة نفسه
# ---------------------------------------------------------
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.monitoring_instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.monitoring_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name

  user_data = templatefile("${path.module}/monitoring_user_data.sh.tpl", {
    discord_webhook_url = var.discord_webhook_url
    aws_region           = var.aws_region
    project_name         = var.project_name
    app_port             = var.app_port
  })

  tags = {
    Name = "${var.project_name}-monitoring"
  }
}

output "monitoring_public_ip" {
  description = "IP سيرفر المراقبة - افتح عليه Prometheus و Alertmanager"
  value       = aws_instance.monitoring.public_ip
}

output "prometheus_url" {
  value = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "alertmanager_url" {
  value = "http://${aws_instance.monitoring.public_ip}:9093"
}
