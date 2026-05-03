resource "aws_security_group" "autopsy_sg" {
  name        = "w1tn3sss-autopsy-sg"
  description = "Autopsy lab - Flask app access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

resource "aws_instance" "autopsy" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.autopsy_sg.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y python3 git

pip3 install flask requests "urllib3<2"

cd /opt
git clone https://github.com/ridamdarji25/AWS-Autopsy.git

cd AWS-Autopsy/Case-01-SSRF-IAM-CapitalOne/app

cat <<EOL > /etc/systemd/system/autopsy-lab.service
[Unit]
Description=AWS Autopsy Lab Flask App
After=network.target

[Service]
WorkingDirectory=/opt/AWS-Autopsy/Case-01-SSRF-IAM-CapitalOne/app
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable autopsy-lab
systemctl start autopsy-lab
EOF

  tags = {
    Name = "w1tn3sss-autopsy-ec2"
  }
}