#!/usr/bin/env python3
"""PayStream Phase 1 — Seed Data Generator.

Generates synthetic data for PostgreSQL (RDS) and DocumentDB, then inserts
in batches. Idempotent: TRUNCATEs all tables before inserting.

Usage:
    python3 scripts/seed_data.py
"""

import os
import random
import uuid
from datetime import datetime, timedelta
from decimal import Decimal

import psycopg2
import psycopg2.extras
import pymongo
import yaml

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "seed_data_config.yaml")

with open(CONFIG_PATH, "r") as f:
    _raw = f.read()

for var in ["RDS_ENDPOINT", "RDS_USERNAME", "RDS_PASSWORD",
            "DOCDB_ENDPOINT", "DOCDB_USERNAME", "DOCDB_PASSWORD"]:
    _raw = _raw.replace(f"${{{var}}}", os.environ.get(var, ""))

CFG = yaml.safe_load(_raw)
PG = CFG["postgresql"]
DOCDB = CFG["documentdb"]
VOLUMES = CFG["volumes"]
BATCH_SIZE = CFG["seed"]["batch_size"]
SEED = CFG["seed"]["random_seed"]

random.seed(SEED)

# ---------------------------------------------------------------------------
# Constants — ALL status values lowercase
# ---------------------------------------------------------------------------

USER_TIERS = ["standard", "premium", "vip"]
USER_TIER_WEIGHTS = [0.70, 0.20, 0.10]
KYC_STATUSES = ["approved", "pending", "rejected"]
KYC_WEIGHTS = [0.85, 0.10, 0.05]

MERCHANT_CATEGORIES = ["electronics", "fashion", "groceries", "restaurants", "travel"]
RISK_TIERS = ["low", "medium", "high"]
RISK_WEIGHTS = [0.60, 0.30, 0.10]
COUNTRIES = ["SAU", "ARE", "BHR", "KWT", "OMN"]

TX_STATUSES = ["approved", "declined", "pending"]
TX_WEIGHTS = [0.85, 0.10, 0.05]

REPAY_STATUSES = ["paid", "overdue", "waived"]
REPAY_WEIGHTS = [0.92, 0.06, 0.02]

INSTALLMENT_COUNTS = [4, 6, 12]
INSTALLMENT_WEIGHTS = [0.80, 0.15, 0.05]
SCHED_STATUSES = ["active", "completed", "defaulted"]
SCHED_STATUS_WEIGHTS = [0.50, 0.40, 0.10]

EVENT_TYPES = ["checkout_started", "browse", "search", "rating", "app_open"]
DEVICE_TYPES = ["ios", "android", "web"]
DEVICE_WEIGHTS = [0.45, 0.40, 0.15]
SCHEMA_VERSIONS = ["v1", "v2", "v3"]
SCHEMA_WEIGHTS = [0.20, 0.30, 0.50]

SESSION_ACTIONS = ["login", "view_dashboard", "download_report", "update_settings"]

BASE_DATE = datetime(2024, 1, 1)
DATE_RANGE_DAYS = 365

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def random_ts(start=BASE_DATE, days=DATE_RANGE_DAYS):
    return start + timedelta(seconds=random.randint(0, days * 86400))


def random_dec(lo, hi, places=2):
    return round(Decimal(str(random.uniform(lo, hi))), places)


def wc(options, weights):
    return random.choices(options, weights=weights, k=1)[0]


def random_phone():
    return f"+9665{random.randint(10000000, 99999999)}"


def random_national_id():
    return f"{random.randint(1000000000, 9999999999)}"


def batch_iter(total, size):
    for off in range(0, total, size):
        yield off, min(size, total - off)


# ---------------------------------------------------------------------------
# PostgreSQL DDL — copied exactly from Phase 1 plan Section 7.2
# ---------------------------------------------------------------------------

PG_DDL = [
    """
    CREATE TABLE IF NOT EXISTS users (
        user_id         BIGSERIAL PRIMARY KEY,
        full_name       VARCHAR(100) NOT NULL,
        email           VARCHAR(150) NOT NULL UNIQUE,
        phone           VARCHAR(20),
        national_id     VARCHAR(20),
        credit_limit    DECIMAL(12, 2) NOT NULL DEFAULT 5000.00,
        credit_tier     VARCHAR(20) NOT NULL DEFAULT 'standard',
        kyc_status      VARCHAR(20) NOT NULL DEFAULT 'pending',
        created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS merchants (
        merchant_id     SERIAL PRIMARY KEY,
        merchant_name   VARCHAR(200) NOT NULL,
        merchant_category VARCHAR(50) NOT NULL,
        risk_tier       VARCHAR(20) NOT NULL DEFAULT 'medium',
        commission_rate DECIMAL(5, 4) NOT NULL DEFAULT 0.0500,
        credit_limit    DECIMAL(15, 2) NOT NULL DEFAULT 500000.00,
        country         VARCHAR(3) NOT NULL DEFAULT 'SAU',
        created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS transactions (
        transaction_id  BIGSERIAL PRIMARY KEY,
        user_id         BIGINT NOT NULL REFERENCES users(user_id),
        merchant_id     INTEGER NOT NULL REFERENCES merchants(merchant_id),
        amount          DECIMAL(12, 2) NOT NULL,
        currency        VARCHAR(3) NOT NULL DEFAULT 'SAR',
        status          VARCHAR(20) NOT NULL,
        decision_latency_ms SMALLINT,
        installment_count   SMALLINT NOT NULL DEFAULT 4,
        created_at      TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS repayments (
        repayment_id    BIGSERIAL PRIMARY KEY,
        transaction_id  BIGINT NOT NULL REFERENCES transactions(transaction_id),
        user_id         BIGINT NOT NULL REFERENCES users(user_id),
        installment_number SMALLINT NOT NULL,
        amount          DECIMAL(12, 2) NOT NULL,
        due_date        DATE NOT NULL,
        paid_at         TIMESTAMP,
        status          VARCHAR(20) NOT NULL DEFAULT 'pending',
        created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS installment_schedules (
        schedule_id     BIGSERIAL PRIMARY KEY,
        transaction_id  BIGINT NOT NULL REFERENCES transactions(transaction_id),
        user_id         BIGINT NOT NULL REFERENCES users(user_id),
        total_amount    DECIMAL(12, 2) NOT NULL,
        installment_count SMALLINT NOT NULL,
        installment_amount DECIMAL(12, 2) NOT NULL,
        start_date      DATE NOT NULL,
        end_date        DATE NOT NULL,
        status          VARCHAR(20) NOT NULL DEFAULT 'active',
        created_at      TIMESTAMP NOT NULL DEFAULT NOW()
    );
    """,
]

PUBLICATION_SQL = """
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'paystream_publication') THEN
        CREATE PUBLICATION paystream_publication FOR ALL TABLES;
    END IF;
END $$;
"""

# ---------------------------------------------------------------------------
# PostgreSQL data generators
# ---------------------------------------------------------------------------


def gen_users(n, offset=0):
    rows = []
    for i in range(n):
        idx = offset + i
        ts = random_ts()
        rows.append((
            f"User {idx}", f"user{idx}@paystream.test", random_phone(),
            random_national_id(), random_dec(1000, 50000),
            wc(USER_TIERS, USER_TIER_WEIGHTS),
            wc(KYC_STATUSES, KYC_WEIGHTS), ts, ts,
        ))
    return rows


def gen_merchants(n):
    rows = []
    for i in range(n):
        ts = random_ts()
        rows.append((
            f"Merchant {i}", random.choice(MERCHANT_CATEGORIES),
            wc(RISK_TIERS, RISK_WEIGHTS),
            random_dec(0.01, 0.10, 4), random_dec(100000, 1000000),
            random.choice(COUNTRIES), ts, ts,
        ))
    return rows


def gen_transactions(n, user_ids, merchant_ids):
    rows = []
    for _ in range(n):
        inst_count = wc(INSTALLMENT_COUNTS, INSTALLMENT_WEIGHTS)
        rows.append((
            random.choice(user_ids), random.choice(merchant_ids),
            random_dec(50, 5000), "SAR",
            wc(TX_STATUSES, TX_WEIGHTS),
            random.randint(50, 500),
            inst_count, random_ts(),
        ))
    return rows


def gen_repayments(n, tx_user_pairs):
    rows = []
    for _ in range(n):
        tx_id, u_id = random.choice(tx_user_pairs)
        status = wc(REPAY_STATUSES, REPAY_WEIGHTS)
        due = random_ts().date()
        paid = (datetime.combine(due, datetime.min.time())
                + timedelta(days=random.randint(0, 5))) if status == "paid" else None
        inst_num = random.randint(1, 4)
        ts = random_ts()
        rows.append((
            tx_id, u_id, inst_num, random_dec(50, 2000),
            due, paid, status, ts, ts,
        ))
    return rows


def gen_installment_schedules(n, tx_user_pairs):
    rows = []
    generated = 0
    while generated < n:
        tx_id, u_id = random.choice(tx_user_pairs)
        inst_count = wc(INSTALLMENT_COUNTS, INSTALLMENT_WEIGHTS)
        total = random_dec(200, 5000)
        inst_amount = round(total / inst_count, 2)
        start = random_ts().date()
        end = start + timedelta(days=30 * inst_count)
        status = wc(SCHED_STATUSES, SCHED_STATUS_WEIGHTS)
        rows.append((
            tx_id, u_id, total, inst_count, inst_amount,
            start, end, status, random_ts(),
        ))
        generated += 1
    return rows


# ---------------------------------------------------------------------------
# DocumentDB data generators
# ---------------------------------------------------------------------------


def gen_app_events(n, user_ids_str, merchant_ids_str):
    docs = []
    for _ in range(n):
        sv = wc(SCHEMA_VERSIONS, SCHEMA_WEIGHTS)
        evt_type = random.choice(EVENT_TYPES)
        mid = random.choice(merchant_ids_str) if evt_type == "checkout_started" else None
        event_data = {"page": f"/page/{random.randint(1, 100)}"}
        if sv in ("v2", "v3"):
            event_data["referrer"] = random.choice(["google", "direct", "social", "email"])
        if sv == "v3":
            event_data["geo"] = {
                "lat": round(random.uniform(21.0, 27.0), 4),
                "lon": round(random.uniform(39.0, 50.0), 4),
            }
        docs.append({
            "event_id": str(uuid.uuid4()),
            "user_id": random.choice(user_ids_str),
            "event_type": evt_type,
            "merchant_id": mid,
            "session_id": str(uuid.uuid4()),
            "device_type": wc(DEVICE_TYPES, DEVICE_WEIGHTS),
            "event_data": str(event_data),
            "created_at": random_ts().isoformat(),
        })
    return docs


def gen_merchant_sessions(n, merchant_ids_str):
    docs = []
    for _ in range(n):
        docs.append({
            "session_id": str(uuid.uuid4()),
            "merchant_id": random.choice(merchant_ids_str),
            "action": random.choice(SESSION_ACTIONS),
            "page": f"/dashboard/{random.choice(['overview', 'reports', 'settings', 'payments'])}",
            "duration_seconds": random.randint(5, 1800),
            "created_at": random_ts().isoformat(),
        })
    return docs


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def seed_postgresql():
    print("Connecting to PostgreSQL...")
    conn = psycopg2.connect(
        host=PG["host"], port=PG["port"], dbname=PG["database"],
        user=PG["username"], password=PG["password"],
    )
    conn.autocommit = True
    cur = conn.cursor()

    print("Creating tables...")
    for ddl in PG_DDL:
        cur.execute(ddl)

    print("Truncating tables (idempotent)...")
    cur.execute("TRUNCATE installment_schedules, repayments, "
                "transactions, merchants, users CASCADE;")

    # --- Users ---
    print(f"Inserting {VOLUMES['users']} users...")
    for off, cnt in batch_iter(VOLUMES["users"], BATCH_SIZE):
        rows = gen_users(cnt, off)
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO users (full_name, email, phone, national_id, "
            "credit_limit, credit_tier, kyc_status, created_at, updated_at) VALUES %s",
            rows,
        )
    cur.execute("SELECT user_id FROM users")
    user_ids = [r[0] for r in cur.fetchall()]

    # --- Merchants ---
    print(f"Inserting {VOLUMES['merchants']} merchants...")
    rows = gen_merchants(VOLUMES["merchants"])
    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO merchants (merchant_name, merchant_category, risk_tier, "
        "commission_rate, credit_limit, country, created_at, updated_at) VALUES %s",
        rows,
    )
    cur.execute("SELECT merchant_id FROM merchants")
    merchant_ids = [r[0] for r in cur.fetchall()]

    # --- Transactions ---
    print(f"Inserting {VOLUMES['transactions']} transactions...")
    for _, cnt in batch_iter(VOLUMES["transactions"], BATCH_SIZE):
        rows = gen_transactions(cnt, user_ids, merchant_ids)
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO transactions (user_id, merchant_id, amount, currency, "
            "status, decision_latency_ms, installment_count, created_at) VALUES %s",
            rows,
        )
    cur.execute("SELECT transaction_id, user_id FROM transactions")
    tx_user_pairs = cur.fetchall()

    # --- Repayments ---
    print(f"Inserting {VOLUMES['repayments']} repayments...")
    for _, cnt in batch_iter(VOLUMES["repayments"], BATCH_SIZE):
        rows = gen_repayments(cnt, tx_user_pairs)
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO repayments (transaction_id, user_id, installment_number, "
            "amount, due_date, paid_at, status, created_at, updated_at) VALUES %s",
            rows,
        )

    # --- Installment Schedules ---
    print(f"Inserting {VOLUMES['installment_schedules']} installment schedules...")
    for _, cnt in batch_iter(VOLUMES["installment_schedules"], BATCH_SIZE):
        rows = gen_installment_schedules(cnt, tx_user_pairs)
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO installment_schedules (transaction_id, user_id, total_amount, "
            "installment_count, installment_amount, start_date, end_date, status, "
            "created_at) VALUES %s",
            rows,
        )

    # --- Publication ---
    print("Creating publication...")
    cur.execute(PUBLICATION_SQL)

    # --- Summary ---
    print("\nPostgreSQL row counts:")
    for tbl in ["users", "merchants", "transactions", "repayments", "installment_schedules"]:
        cur.execute(f"SELECT count(*) FROM {tbl}")
        print(f"  {tbl}: {cur.fetchone()[0]}")

    cur.close()
    conn.close()
    return user_ids, merchant_ids


def seed_documentdb(user_ids, merchant_ids):
    print("\nConnecting to DocumentDB...")
    conn_str = (
        f"mongodb://{DOCDB['username']}:{DOCDB['password']}@{DOCDB['host']}:{DOCDB['port']}/"
        f"{DOCDB['database']}?tls=true&tlsCAFile={DOCDB['tls_ca_file']}"
        f"&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
    )
    client = pymongo.MongoClient(conn_str)
    db = client[DOCDB["database"]]

    # Convert IDs to strings for DocumentDB
    user_ids_str = [str(uid) for uid in user_ids]
    merchant_ids_str = [str(mid) for mid in merchant_ids]

    print("Dropping existing collections...")
    db.drop_collection("app_events")
    db.drop_collection("merchant_sessions")

    # --- App Events ---
    print(f"Inserting {VOLUMES['app_events']} app_events...")
    for _, cnt in batch_iter(VOLUMES["app_events"], BATCH_SIZE):
        docs = gen_app_events(cnt, user_ids_str, merchant_ids_str)
        db.app_events.insert_many(docs)

    # --- Merchant Sessions ---
    print(f"Inserting {VOLUMES['merchant_sessions']} merchant_sessions...")
    for _, cnt in batch_iter(VOLUMES["merchant_sessions"], BATCH_SIZE):
        docs = gen_merchant_sessions(cnt, merchant_ids_str)
        db.merchant_sessions.insert_many(docs)

    # --- Summary ---
    print("\nDocumentDB row counts:")
    print(f"  app_events: {db.app_events.count_documents({})}")
    print(f"  merchant_sessions: {db.merchant_sessions.count_documents({})}")

    client.close()


def main():
    print("=" * 50)
    print("PayStream Seed Data Generator")
    print("=" * 50)
    user_ids, merchant_ids = seed_postgresql()
    seed_documentdb(user_ids, merchant_ids)
    print("\n=== Seeding Complete ===")


if __name__ == "__main__":
    main()
