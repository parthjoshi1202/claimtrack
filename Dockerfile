FROM python:3.12-slim

# Prevent Python from writing .pyc files and enable unbuffered logging
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1. Create dedicated non-root system user early
RUN groupadd -r appgroup && useradd -r -g appgroup -s /sbin/nologin appuser

# 2. Copy dependencies first and install as root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. Copy application files with ownership pre-assigned (prevents duplicate layer size)
COPY --chown=appuser:appgroup app/ ./app

# 4. Switch to non-root user
USER appuser

EXPOSE 8000

CMD ["fastapi", "run", "app/main.py", "--port", "8000"]