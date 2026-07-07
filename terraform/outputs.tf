output "alb_dns_name" {
  description = "اللينك اللي هتفتح بيه الموقع بعد التنفيذ"
  value       = aws_lb.app_alb.dns_name
}

output "asg_name" {
  description = "اسم الـ Auto Scaling Group (هتحتاجه لو عايز تعمل عليه أي أمر AWS CLI لاحقًا)"
  value       = aws_autoscaling_group.app_asg.name
}

output "security_group_app" {
  description = "اسم الـ Security Group الخاصة بالتطبيق"
  value       = aws_security_group.app_sg.id
}
