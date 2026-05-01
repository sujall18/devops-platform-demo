# Stage 1: install dependencies into a clean layer
FROM python:3.12-slim AS builder
WORKDIR /install
COPY app/requirements.txt .
RUN pip install --prefix=/install/deps --no-cache-dir -r requirements.txt

# Stage 2: lean production image
FROM python:3.12-slim AS runtime
WORKDIR /app

# Non-root user — security best practice
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

COPY --from=builder /install/deps /usr/local
COPY app/ .

USER appuser

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "app:app"]
