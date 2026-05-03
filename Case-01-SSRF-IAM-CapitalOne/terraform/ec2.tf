resource "aws_security_group" "autopsy_sg" {
  name        = "${var.prefix}-autopsy-sg"
  description = "Autopsy lab — Flask app access"

  ingress {
    description = "Flask SSRF app port"
    from_port   = 5000
    to_port     = 5000
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

resource "aws_instance" "autopsy_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.autopsy_profile.name
  vpc_security_group_ids = [aws_security_group.autopsy_sg.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.prefix}-autopsy-ec2"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip
    pip3 install flask requests
  EOF
}