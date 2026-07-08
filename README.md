# Self-Healing Infrastructure

مشروع بنية تحتية ذاتية الإصلاح (Self-Healing Infrastructure) مبني بالكامل باستخدام أدوات DevOps حديثة. التطبيق مراقَب باستمرار، وأي عطل بيتصلح تلقائيًا من غير تدخل بشري.

## الفكرة العامة

```
                    ┌─────────────────┐
                    │   GitHub Repo    │
                    └────────┬────────┘
                             │ git push
                             ▼
                  ┌──────────────────────┐
                  │   GitHub Actions      │  (CI/CD)
                  │ يبني ويرفع صورة Docker │
                  └──────────┬───────────┘
                             │ docker push
                             ▼
                    ┌─────────────────┐
                    │    Docker Hub    │
                    └────────┬────────┘
                             │ docker pull
                             ▼
        ┌────────────────────────────────────────┐
        │              AWS (Terraform)             │
        │  ┌────────────────────────────────────┐  │
        │  │   Application Load Balancer          │  │
        │  └──────────────┬───────────────────────┘  │
        │                 ▼                          │
        │  ┌────────────────────────────────────┐  │
        │  │   Auto Scaling Group (EC2 + Docker)  │  │
        │  └──────────────┬───────────────────────┘  │
        └─────────────────┼──────────────────────────┘
                           │ /metrics
                           ▼
                  ┌─────────────────┐
                  │    Prometheus    │  (Monitoring)
                  └────────┬────────┘
                           │ alert rules
                           ▼
                  ┌─────────────────┐
                  │   Alertmanager   │
                  └────────┬────────┘
                    ┌──────┴──────┐
                    ▼             ▼
            ┌──────────────┐  ┌─────────────────┐
            │   Discord     │  │ Webhook Receiver │
            │ (إشعار فقط)  │  │  (Automation)     │
            └──────────────┘  └────────┬─────────┘
                                        │ يشغّل
                                        ▼
                               ┌─────────────────┐
                               │     Ansible      │
                               │ (يصلح المشكلة)  │
                               └─────────────────┘
```

## الأدوات المستخدمة

| الأداة | الدور |
|---|---|
| **Flask** | تطبيق ويب بسيط (To-Do List) |
| **Docker** | تغليف التطبيق في صورة قابلة للنقل |
| **Docker Hub** | استضافة صور Docker |
| **GitHub** | إدارة الكود المصدري |
| **GitHub Actions** | CI/CD - بناء ورفع الصورة تلقائيًا عند كل push |
| **Terraform** | بناء البنية التحتية على AWS (IaC) |
| **AWS (EC2, ALB, ASG)** | استضافة التطبيق مع قدرة استبدال ذاتي للسيرفرات المعطوبة |
| **Prometheus** | مراقبة التطبيق وجمع المقاييس (Metrics) |
| **Alertmanager** | تحويل المقاييس غير الطبيعية إلى تنبيهات |
| **Discord** | استقبال الإشعارات |
| **Ansible** | تنفيذ الإصلاح التلقائي (مسح اللوجز / إعادة التشغيل) |

## هيكل الريبو

```
self-healing-infra/
├── app/                      # التطبيق
│   ├── todo_app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
│
├── terraform/                # البنية التحتية على AWS
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── user_data.sh
│   └── terraform.tfvars.example
│
├── monitoring/                # المراقبة والتنبيهات
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   └── alertmanager.yml      (محلي فقط - غير مرفوع لاحتوائه بيانات حساسة)
│
├── ansible/                   # الإصلاح التلقائي
│   └── playbook.yml
│
├── webhook-receiver/          # حلقة الوصل بين Alertmanager و Ansible
│   ├── webhook.py
│   └── Dockerfile
│
├── .github/workflows/
│   └── deploy.yml             # CI/CD pipeline
│
├── docker-compose.yml         # تشغيل كل شيء محليًا دفعة واحدة
└── README.md
```

## التشغيل المحلي (بدون AWS)

```bash
# 1. عدّل monitoring/alertmanager.yml وضع رابط Discord webhook الخاص بك

# 2. شغّل كل شيء
docker compose up -d --build

# 3. تأكد من حالة الخدمات
docker compose ps
```

بعد التشغيل:
- **التطبيق**: http://localhost:5001
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## نشر البنية التحتية على AWS

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# عدّل key_name بالـ Key Pair الخاص بك

terraform init
terraform plan
terraform apply
```

بعد الانتهاء، سيظهر رابط الموقع في `alb_dns_name`.

**لإيقاف كل شيء وتوفير التكلفة:**
```bash
terraform destroy
```

## اختبار الإصلاح الذاتي (Self-Healing)

```bash
# محاكاة عطل: إيقاف الكونتينر يدويًا
docker stop todo-app-container

# راقب الأحداث
docker compose logs -f webhook-receiver
```

خلال ثوانٍ:
1. Prometheus يكتشف أن التطبيق واقع (`AppDown` / `InstanceDown`)
2. Alertmanager يرسل تنبيه لـ Discord ويستدعي webhook-receiver
3. Ansible يعيد تشغيل الكونتينر تلقائيًا
4. التطبيق يعود للعمل من دون أي تدخل بشري

## اختبار تنبيه معدل الأخطاء

```bash
for i in {1..30}; do curl -s http://localhost:5001/simulate/error > /dev/null; done
```

راقب `http://localhost:9090/alerts` — سترى `HighErrorRate` ينتقل من Pending إلى Firing خلال 30 ثانية، ثم تصلك رسالة على Discord.

## ملاحظات أمان

- `terraform.tfvars` و `monitoring/alertmanager.yml` مستثناة من Git (`.gitignore`) لأنها تحتوي بيانات حساسة (Key Pair name, Discord webhook URL).
- بيانات Docker Hub مخزنة في **GitHub Secrets**، وليست مكتوبة في الكود.
