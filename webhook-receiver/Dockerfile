FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir flask ansible docker

RUN ansible-galaxy collection install community.docker

WORKDIR /app
COPY webhook-receiver/webhook.py .
COPY ansible /ansible

EXPOSE 5001

CMD ["python", "webhook.py"]
