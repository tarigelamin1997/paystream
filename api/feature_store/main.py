"""FastAPI application entry point for the PayStream Feature Store API."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .clickhouse_client import ClickHousePool
from .routes import router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
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

app.include_router(router)
