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

  # 🔥 IAM FIX (MAIN)
  iam_instance_profile = aws_iam_instance_profile.autopsy_profile.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  user_data = <<-EOF
#!/bin/bash
set -e

yum update -y
yum install -y python3

pip3 install flask requests "urllib3<2"

mkdir -p /opt/autopsy-lab
cd /opt/autopsy-lab

cat <<'EOL' > app.py
from flask import Flask, request, jsonify
import requests

app = Flask(__name__)

@app.route('/')
def index():
    return """
<!DOCTYPE html>
<html>
<head>
  <title>Autopsy Lab · Case 01</title>
  <style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0d1117;color:#e6edf3;font-family:'Courier New',monospace;
min-height:100vh;display:flex;align-items:center;justify-content:center}
.container{max-width:560px;width:100%;padding:2rem}
.badge{display:inline-block;background:#f851491a;color:#f85149;
border:1px solid #f8514933;padding:4px 12px;border-radius:20px;
font-size:11px;letter-spacing:.08em;margin-bottom:1.5rem}
h1{font-size:22px;color:#e6edf3;margin-bottom:6px}
h1 span{color:#f85149}
.subtitle{font-size:13px;color:#8b949e;margin-bottom:2rem}
.divider{border:none;border-top:1px solid #21262d;margin:1.5rem 0}
.endpoint-label{font-size:11px;color:#8b949e;text-transform:uppercase;
letter-spacing:.08em;margin-bottom:8px}
.endpoint{background:#161b22;border:1px solid #30363d;border-radius:8px;
padding:12px 14px;font-size:12px;color:#3fb950;margin-bottom:8px}
.endpoint span{color:#58a6ff}
.warn-box{background:#f851490d;border:1px solid #f8514933;border-radius:8px;
padding:14px;margin-top:1.5rem}
.warn-title{color:#f85149;font-size:12px;font-weight:bold;margin-bottom:6px}
.warn-text{color:#8b949e;font-size:11px;line-height:1.6}
.dot{display:inline-block;width:6px;height:6px;background:#3fb950;
border-radius:50%;margin-right:8px;animation:pulse 2s infinite}

/* 🔥 FIXED LINE (no terraform error) */
@keyframes pulse { 0%,100% { opacity:1 } 50% { opacity:0.3 } }

  </style>
</head>
<body>
<div class="container">
  <div class="badge">⚠️ INTENTIONALLY VULNERABLE</div>
  <h1>🔪 AWS <span>Autopsy</span></h1>
  <p class="subtitle">Case #01 · Internal Fetch Service · SSRF Lab</p>
  <hr class="divider">
  <p class="endpoint-label">Available Endpoints</p>
  <div class="endpoint"><span>GET</span> /fetch?url=&lt;target_url&gt;</div>
  <div class="endpoint"><span>GET</span> /health</div>
  <hr class="divider">
  <p class="endpoint-label">Try It</p>
  <div class="endpoint">/fetch?url=http://169.254.169.254/latest/meta-data/</div>
  <div class="warn-box">
    <p class="warn-title"><span class="dot"></span>Security Warning</p>
    <p class="warn-text">
      This application is intentionally vulnerable to SSRF.<br><br>
      Designed for AWS Autopsy lab series.<br><br>
      Do not deploy in production.
    </p>
  </div>
</div>
</body>
</html>
"""

@app.route('/health')
def health():
    return jsonify({"status": "running"})

@app.route('/fetch')
def fetch():
    url = request.args.get("url")

    if not url:
        return jsonify({"error": "Missing url"}), 400

    try:
        r = requests.get(url, timeout=5)
        return r.text
    except Exception as e:
        return jsonify({"error": str(e)}), 500

app.run(host="0.0.0.0", port=5000)
EOL

cat <<'EOL' > /etc/systemd/system/autopsy-lab.service
[Unit]
Description=AWS Autopsy Lab Flask App
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/autopsy-lab/app.py
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