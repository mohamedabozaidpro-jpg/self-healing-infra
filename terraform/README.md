# Terraform - Self Healing Infrastructure

## الملفات
- `main.tf` — كل الموارد (VPC data, Security Groups, ALB, Launch Template, ASG)
- `variables.tf` — كل القيم القابلة للتعديل
- `outputs.tf` — النتائج بعد التنفيذ (اللينك، اسم الـ ASG...)
- `user_data.sh` — سكربت التجهيز التلقائي لأي instance جديد (تثبيت Docker وتشغيل التطبيق)
- `terraform.tfvars.example` — نموذج قيم، انسخه باسم `terraform.tfvars` وعدّل عليه

## المتطلبات قبل التشغيل
1. حساب AWS + AWS CLI مضبوط (`aws configure`) بصلاحيات كافية (EC2, VPC, ELB, Auto Scaling)
2. Terraform مثبت على جهازك (نسخة 1.5 أو أحدث)
3. Key Pair موجود بالفعل على AWS في نفس الـ region (لعمل SSH لو احتجت)

## خطوات التشغيل

```bash
# انسخ ملف القيم وعدّل عليه
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars   # حط اسم الـ key_name بتاعك

# جهّز المشروع (أول مرة بس)
terraform init

# شوف هيتعمل ايه قبل التنفيذ الفعلي
terraform plan

# نفّذ فعليًا وابني كل حاجة على AWS
terraform apply
# هيسألك تأكيد، اكتب: yes
```

بعد ما يخلص (بياخد 2-5 دقايق)، هيطبعلك:
```
alb_dns_name = "self-healing-app-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
```

افتح اللينك ده في المتصفح، المفروض تشوف قائمة المهام شغالة.

## اختبار الـ Self-Healing
```bash
# جيب الـ IP بتاع أي instance من الـ EC2 console، وادخل عليه SSH
ssh -i your-key.pem ubuntu@<instance-ip>

# جرب توقف الكونتينر يدويًا (محاكاة عطل)
sudo docker stop todo-app-container

# راقب الـ ASG - المفروض بعد شوية يعتبر الـ instance "unhealthy"
# ويستبدله تلقائيًا بواحد جديد سليم
```

## لمسح كل حاجة بعد التجربة (مهم جدًا لتجنب فواتير غير متوقعة)
```bash
terraform destroy
# اكتب: yes
```
