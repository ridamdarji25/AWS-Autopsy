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
set -e
exec > /var/log/autopsy-setup.log 2>&1

# Install dependencies
yum update -y
yum install -y python3 python3-pip

pip3 install --upgrade pip
pip3 install flask requests

# Create app directory
mkdir -p /opt/autopsy-lab
chown ec2-user:ec2-user /opt/autopsy-lab

# Write Flask app
cat > /opt/autopsy-lab/app.py << 'PYEOF'
#!/usr/bin/env python3
from flask import Flask, request, jsonify
import requests
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

@app.route('/')
def index():
    return """
    <html>
    <body style="background:#0d1117;color:#3fb950;font-family:monospace;padding:2rem">
    <h2>🔪 AWS Autopsy Lab | Case 01</h2>
    <p>Use: /fetch?url=</p>
    </body>
    </html>
    """

@app.route('/health')
def health():
    return jsonify({"status":"running"})

# ⚠️ SSRF VULNERABLE ENDPOINT
@app.route('/fetch')
def fetch():
    url = request.args.get('url','')
    if not url:
        return jsonify({"error":"url required"}),400
    try:
        r = requests.get(url,timeout=5)
        return r.text
    except Exception as e:
        return str(e)

if __name__ == "__main__":
    app.run(host="0.0.0.0",port=5000)
PYEOF

# Create service
cat > /etc/systemd/system/autopsy-lab.service << 'SVCEOF'
[Unit]
Description=AWS Autopsy Lab Flask App
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/autopsy-lab
ExecStart=/usr/bin/python3 /opt/autopsy-lab/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# Start service
systemctl daemon-reload
systemctl enable autopsy-lab
systemctl start autopsy-lab

echo "SETUP DONE" >> /var/log/autopsy-setup.log
EOF
}