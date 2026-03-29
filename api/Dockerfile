FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

WORKDIR /app
COPY --from=builder /install /usr/local
COPY feature_store/ feature_store/

EXPOSE 8000

CMD ["uvicorn", "feature_store.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
