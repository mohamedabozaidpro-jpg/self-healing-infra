import subprocess
import logging
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# أسماء التنبيهات اللي بتخلي الـ playbook يشتغل تلقائيًا
HEALING_TRIGGERS = {"AppDown", "InstanceDown"}


@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.get_json(force=True, silent=True) or {}
    alerts = data.get("alerts", [])

    if not alerts:
        return jsonify(status="no alerts received"), 200

    triggered = []

    for alert in alerts:
        alert_name = alert.get("labels", {}).get("alertname", "")
        status = alert.get("status", "")

        log.info(f"استلمت تنبيه: {alert_name} - الحالة: {status}")

        if alert_name in HEALING_TRIGGERS and status == "firing":
            log.info(f"تشغيل الإصلاح التلقائي بسبب: {alert_name}")
            result = run_ansible_playbook()
            triggered.append({"alert": alert_name, "result": result})

    return jsonify(status="processed", triggered=triggered), 200


def run_ansible_playbook():
    try:
        result = subprocess.run(
            ["ansible-playbook", "/ansible/playbook.yml"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        log.info(result.stdout)
        if result.returncode != 0:
            log.error(result.stderr)
        return "success" if result.returncode == 0 else "failed"
    except Exception as e:
        log.error(f"فشل تشغيل Ansible: {e}")
        return "error"


@app.route("/health")
def health():
    return jsonify(status="healthy"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
