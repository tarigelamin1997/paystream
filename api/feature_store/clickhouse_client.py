"""ClickHouse connection pool using clickhouse-driver native TCP."""

import logging
from queue import Empty, Queue

from clickhouse_driver import Client

from .config import CLICKHOUSE_HOST, CLICKHOUSE_PORT, POOL_SIZE

logger = logging.getLogger(__name__)


class ClickHousePool:
    """Simple connection pool wrapping clickhouse-driver Client instances.

    Pre-creates POOL_SIZE connections on init. Callers acquire/release
    via context manager or explicit get/put.
    """

    def __init__(
        self,
        host: str = CLICKHOUSE_HOST,
        port: int = CLICKHOUSE_PORT,
        pool_size: int = POOL_SIZE,
    ) -> None:
        self._host = host
        self._port = port
        self._pool: Queue[Client] = Queue(maxsize=pool_size)
        for _ in range(pool_size):
            self._pool.put(self._create_connection())
        logger.info(
            "ClickHouse pool initialized: host=%s port=%d size=%d",
            host,
            port,
            pool_size,
        )

    def _create_connection(self) -> Client:
        return Client(host=self._host, port=self._port)

    def get(self, timeout: float = 5.0) -> Client:
        """Acquire a connection from the pool."""
        try:
            return self._pool.get(timeout=timeout)
        except Empty:
            raise RuntimeError("ClickHouse connection pool exhausted")

    def put(self, conn: Client) -> None:
        """Return a connection to the pool."""
        self._pool.put(conn)

    def execute(self, query: str, params: dict | None = None) -> list:
        """Execute a query using a pooled connection, returning rows."""
        conn = self.get()
        try:
            return conn.execute(query, params or {})
        except Exception:
            # Replace broken connection
            try:
                conn.disconnect()
            except Exception:
                pass
            self._pool.put(self._create_connection())
            raise
        else:
            self.put(conn)

    def ping(self) -> bool:
        """Check pool health by pinging one connection."""
        conn = self.get()
        try:
            conn.execute("SELECT 1")
            return True
        except Exception:
            return False
        finally:
            self.put(conn)

    def close(self) -> None:
        """Disconnect all pooled connections."""
        while not self._pool.empty():
            try:
                conn = self._pool.get_nowait()
                conn.disconnect()
            except Empty:
                break
