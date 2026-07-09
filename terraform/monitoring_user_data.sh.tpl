#!/bin/bash
set -e

# ============================================================
# 1. تثبيت الأدوات الأساسية
# ============================================================
apt-get update -y
apt-get install -y docker.io docker-compose-v2 python3-pip awscli
systemctl start docker
systemctl enable docker

pip3 install ansible boto3 botocore flask

ansible-galaxy collection install amazon.aws community.docker

mkdir -p /opt/monitoring/ansible
mkdir -p /home/ubuntu/.ssh
chown -R ubuntu:ubuntu /home/ubuntu/.ssh

# ============================================================
# 2. إعداد Ansible - Dynamic Inventory (يكتشف الـ EC2 instances تلقائيًا)
# ============================================================
cat > /opt/monitoring/ansible/aws_ec2.yml << EOF
plugin: amazon.aws.aws_ec2
regions:
  - ${aws_region}
filters:
  tag:Name: "${project_name}-instance"
  instance-state-name: running
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
EOF

cat > /opt/monitoring/ansible/ansible.cfg << EOF
[defaults]
remote_user = ubuntu
private_key_file = /home/ubuntu/.ssh/app-key.pem
host_key_checking = False
inventory = /opt/monitoring/ansible/aws_ec2.yml

[inventory]
enable_plugins = amazon.aws.aws_ec2
EOF

cat > /opt/monitoring/ansible/playbook.yml << 'EOF'
---
- name: Self-healing playbook - restart app on real EC2 instances
  hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: مسح ملف اللوجز جوه الكونتينر
      community.docker.docker_container_exec:
        container: todo-app-container
        command: sh -c "truncate -s 0 /app/logs/app.log 2>/dev/null || true"
      ignore_errors: true

    - name: عمل Restart للكونتينر
      community.docker.docker_container:
        name: todo-app-container
        state: started
        restart: true
EOF

# ============================================================
# 3. إعداد Prometheus - يكتشف الـ EC2 instances تلقائيًا (Service Discovery)
# ============================================================
mkdir -p /opt/monitoring/prometheus

cat > /opt/monitoring/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 10s
  evaluation_interval: 10s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

rule_files:
  - "alert.rules.yml"

scrape_configs:
  - job_name: "todo-app-ec2"
    ec2_sd_configs:
      - region: ${aws_region}
        port: ${app_port}
        filters:
          - name: tag:Name
            values: ["${project_name}-instance"]
          - name: instance-state-name
            values: ["running"]
    relabel_configs:
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance_id
      - source_labels: [__meta_ec2_availability_zone]
        target_label: availability_zone
EOF

cat > /opt/monitoring/prometheus/alert.rules.yml << 'EOF'
groups:
  - name: todo-app-alerts
    rules:
      - alert: HighErrorRate
        expr: (rate(app_requests_errors_total[1m]) / clamp_min(rate(app_requests_total[1m]), 0.0001)) > 0.05
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "معدل الأخطاء تعدى 5%"
          description: "معدل الأخطاء في التطبيق تعدى 5% على السيرفر {{ $labels.instance }}"

      - alert: InstanceDown
        expr: up{job="todo-app-ec2"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "سيرفر واقع فعليًا على AWS"
          description: "Prometheus فشل في الوصول لـ instance {{ $labels.instance_id }}"
EOF

# ============================================================
# 4. إعداد Alertmanager
# ============================================================
mkdir -p /opt/monitoring/alertmanager

cat > /opt/monitoring/alertmanager/alertmanager.yml << EOF
global:
  resolve_timeout: 1m

route:
  receiver: "discord"
  group_by: ["alertname"]
  group_wait: 5s
  group_interval: 30s
  repeat_interval: 2m
  routes:
    - matchers:
        - alertname = "InstanceDown"
      receiver: "self-healing"

receivers:
  - name: "discord"
    discord_configs:
      - webhook_url: "${discord_webhook_url}"
        send_resolved: true
        title: "{{ .CommonLabels.alertname }}"
        message: "{{ .CommonAnnotations.description }}"

  - name: "self-healing"
    discord_configs:
      - webhook_url: "${discord_webhook_url}"
        send_resolved: true
        title: "🔧 Self-Healing Triggered: {{ .CommonLabels.alertname }}"
        message: "{{ .CommonAnnotations.description }}"
    webhook_configs:
      - url: "http://host.docker.internal:5001/webhook"
        send_resolved: false
EOF

# ============================================================
# 5. سيرفر الـ webhook (يستقبل من Alertmanager ويشغل Ansible) - عملية Python طبيعية
# ============================================================
cat > /opt/monitoring/webhook.py << 'EOF'
import subprocess
import logging
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

HEALING_TRIGGERS = {"InstanceDown"}


@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True, silent=True) or {}
    alerts = data.get("alerts", [])
    triggered = []

    for alert in alerts:
        alert_name = alert.get("labels", {}).get("alertname", "")
        status = alert.get("status", "")
        log.info(f"استلمت تنبيه: {alert_name} - {status}")

        if alert_name in HEALING_TRIGGERS and status == "firing":
            result = subprocess.run(
                ["ansible-playbook", "/opt/monitoring/ansible/playbook.yml"],
                capture_output=True, text=True, timeout=120,
                cwd="/opt/monitoring/ansible"
            )
            log.info(result.stdout)
            if result.returncode != 0:
                log.error(result.stderr)
            triggered.append({"alert": alert_name, "ok": result.returncode == 0})

    return jsonify(status="processed", triggered=triggered), 200


@app.route("/health")
def health():
    return jsonify(status="healthy"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

# تشغيل الـ webhook كـ systemd service عشان يفضل شغال ويعيد التشغيل لوحده لو وقع
cat > /etc/systemd/system/webhook.service << 'EOF'
[Unit]
Description=Alertmanager Webhook Receiver
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/monitoring/webhook.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable webhook
systemctl start webhook

# ============================================================
# 6. docker-compose لتشغيل Prometheus و Alertmanager
# ============================================================
cat > /opt/monitoring/docker-compose.yml << 'EOF'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alert.rules.yml:/etc/prometheus/alert.rules.yml:ro
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped
EOF

chmod -R 644 /opt/monitoring/prometheus/*.yml /opt/monitoring/alertmanager/*.yml
cd /opt/monitoring
docker compose up -d

echo "===================================================="
echo "سيرفر المراقبة جاهز."
echo "لازم دلوقتي تنسخ ملف الـ .pem بتاعك لهنا يدويًا:"
echo "scp -i your-key.pem your-key.pem ubuntu@<monitoring-ip>:/home/ubuntu/.ssh/app-key.pem"
echo "===================================================="
