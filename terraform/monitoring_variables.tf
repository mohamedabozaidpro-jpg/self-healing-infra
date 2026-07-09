variable "monitoring_instance_type" {
  description = "نوع سيرفر المراقبة"
  type        = string
  default     = "t3.micro"
}

variable "discord_webhook_url" {
  description = "رابط Discord Webhook لاستقبال التنبيهات (سري - لا يُكتب في الكود مباشرة)"
  type        = string
  sensitive   = true
}
