variable "aws_region" {
  description = "المنطقة (Region) اللي هيتبنى فيها كل حاجة"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "اسم المشروع، بيتحط كـ prefix لكل الموارد عشان تتعرف بسهولة"
  type        = string
  default     = "self-healing-app"
}

variable "instance_type" {
  description = "نوع سيرفر الـ EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "اسم الـ Key Pair بتاعك على AWS (لازم يكون موجود بالفعل في نفس الـ Region) عشان تقدر تعمل SSH"
  type        = string
}

variable "docker_image" {
  description = "اسم الصورة الكاملة على Docker Hub مع الـ tag"
  type        = string
  default     = "mohamedabozaid97531/todo-app:v1"
}

variable "app_port" {
  description = "البورت اللي التطبيق شغال عليه جوه الكونتينر"
  type        = number
  default     = 5000
}

variable "min_size" {
  description = "أقل عدد instances في الـ Auto Scaling Group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "أكبر عدد instances في الـ Auto Scaling Group"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "العدد المطلوب تشغيله في الوضع الطبيعي"
  type        = number
  default     = 2
}

variable "allowed_ssh_cidr" {
  description = "الـ IP (أو النطاق) المسموح له بعمل SSH على السيرفرات. استخدم IP بتاعك بس + /32 للأمان"
  type        = string
  default     = "0.0.0.0/0" # للتجربة فقط - في الإنتاج حدد IP بتاعك بالظبط
}
