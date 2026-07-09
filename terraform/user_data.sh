#!/bin/bash
set -e

# تحديث النظام وتنصيب Docker
apt-get update -y
apt-get install -y docker.io python3-pip
systemctl start docker
systemctl enable docker

# مطلوبة عشان Ansible (من سيرفر المراقبة) يقدر يتحكم في الكونتينر عن بعد
pip3 install docker requests

# سحب الصورة من Docker Hub وتشغيلها
docker pull ${docker_image}
docker run -d \
  --name todo-app-container \
  --restart unless-stopped \
  -p ${app_port}:${app_port} \
  ${docker_image}
