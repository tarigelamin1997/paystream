"""FastAPI application entry point for the PayStream Feature Store API."""

import json
import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from .clickhouse_client import ClickHousePool
from .routes import router


class JSONFormatter(logging.Formatter):
    """Structured JSON log formatter for CloudWatch Logs Insights."""

    def format(self, record):
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
        }
        if record.exc_info and record.exc_info[0]:
            entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(entry)


handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.root.handlers = [handler]
logging.root.setLevel(logging.INFO)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage ClickHouse connection pool lifecycle."""
    logger.info("Initializing ClickHouse connection pool")
    app.state.ch_pool = ClickHousePool()
    yield
    logger.info("Shutting down ClickHouse connection pool")
    app.state.ch_pool.close()


app = FastAPI(
    title="PayStream Feature Store API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log every request with structured context for CloudWatch Insights."""
    start = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000, 2)
    logger.info(
        "request %s %s -> %d (%.1fms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response


app.include_router(router)
