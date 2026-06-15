import psycopg2
import psycopg2.extras
import logging
import sys
import argparse
from datetime import datetime, date

# Import credentials from separate config files
from db_source_config import DB_SOURCE
from db_target_config import DB_TARGET


# ---------------------------------------------------------------------------
# TABLE CONFIGURATION  ← change schema and table names here
# ---------------------------------------------------------------------------
SOURCE_SCHEMA = "cvm_data"
SOURCE_TABLE_NAME = "cvm_taker_border_region_mtd_init"

TARGET_SCHEMA = "cvm"
TARGET_TABLE_NAME = "cvm_taker_border_region_mtd_init"

SOURCE_TABLE = f"{SOURCE_SCHEMA}.{SOURCE_TABLE_NAME}"
TARGET_TABLE = f"{TARGET_SCHEMA}.{TARGET_TABLE_NAME}"


# ---------------------------------------------------------------------------
# Logging Setup
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(f"../Log/etl_sync_{TARGET_TABLE_NAME}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"),
    ],
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Column Definitions
# ---------------------------------------------------------------------------

COLUMNS = [
    "d_date",
    "strmonth",
    "region_sales",
    "tower",
    "wltype",
    "campaign_initiatives",
    "revenue",
    "trx",
    "unique_taker"
]

COLUMNS_SQL = ", ".join(COLUMNS)
PLACEHOLDERS = ", ".join([f"%({col})s" for col in COLUMNS])
UPDATE_SET = ", ".join(
    [f"{col} = EXCLUDED.{col}" for col in COLUMNS if col != "d_date"]
)


# ---------------------------------------------------------------------------
# Database Helpers
# ---------------------------------------------------------------------------
def get_connection(config: dict):
    """Create and return a psycopg2 connection."""
    try:
        conn = psycopg2.connect(
            host=config["host"],
            port=config["port"],
            dbname=config["database"],
            user=config["user"],
            password=config["password"],
            options=config.get("options", ""),
            connect_timeout=30,
        )
        conn.autocommit = False
        return conn
    except psycopg2.OperationalError as e:
        logger.error(f"Connection failed to {config['host']}/{config['database']}: {e}")
        raise


# ---------------------------------------------------------------------------
# Core ETL Functions
# ---------------------------------------------------------------------------
def fetch_source_data(conn, d_date: str) -> list[dict]:
    """
    Fetch all rows from source table matching the given d_date.
    Returns a list of dicts (one per row).
    """
    query = f"""
        SELECT {COLUMNS_SQL}
        FROM   {SOURCE_TABLE}
        WHERE  d_date = %(d_date)s
        ORDER  BY d_date
    """
    logger.info(f"Fetching source data for d_date = {d_date} ...")
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute(query, {"d_date": d_date})
        rows = cur.fetchall()
    logger.info(f"  → {len(rows):,} rows fetched from source.")
    return [dict(row) for row in rows]


def delete_target_by_date(conn, d_date: str) -> int:
    """
    Delete existing rows in the target table for the given d_date
    before re-inserting (full-replace strategy).
    Returns number of deleted rows.
    """
    query = f"""
        DELETE FROM {TARGET_TABLE}
        WHERE  d_date = %(d_date)s
    """
    with conn.cursor() as cur:
        cur.execute(query, {"d_date": d_date})
        deleted = cur.rowcount
    logger.info(f"  → {deleted:,} existing rows deleted from target.")
    return deleted


def upsert_target_data(conn, rows: list[dict], batch_size: int = 1000) -> int:
 
    if not rows:
        logger.info("  → No rows to insert.")
        return 0
    
    query = f"""
        INSERT INTO {TARGET_TABLE} ({COLUMNS_SQL})
        VALUES ({PLACEHOLDERS})
    """

    total = 0
    with conn.cursor() as cur:
        for i in range(0, len(rows), batch_size):
            batch = rows[i : i + batch_size]
            psycopg2.extras.execute_batch(cur, query, batch, page_size=batch_size)
            total += len(batch)
            logger.info(f"  → Upserted batch {i // batch_size + 1}: {total:,}/{len(rows):,} rows")

    return total


def sync_by_d_date(d_date: str, strategy: str = "upsert") -> None:
    logger.info("=" * 60)
    logger.info(f"START SYNC  |  d_date={d_date}  |  strategy={strategy}")
    logger.info(f"  Source : {SOURCE_TABLE}  @  {DB_SOURCE['host']}")
    logger.info(f"  Target : {TARGET_TABLE}  @  {DB_TARGET['host']}")
    logger.info("=" * 60)

    src_conn = tgt_conn = None
    try:
        src_conn = get_connection(DB_SOURCE)
        tgt_conn = get_connection(DB_TARGET)

        # 1. Fetch
        rows = fetch_source_data(src_conn, d_date)
        if not rows:
            logger.warning(f"No data found in source for d_date={d_date}. Exiting.")
            return

        # 2. Write to target
        if strategy == "replace":
            delete_target_by_date(tgt_conn, d_date)
            query = f"""
                INSERT INTO {TARGET_TABLE} ({COLUMNS_SQL})
                VALUES ({PLACEHOLDERS})
            """
            with tgt_conn.cursor() as cur:
                psycopg2.extras.execute_batch(cur, query, rows, page_size=1000)
            inserted = len(rows)
            logger.info(f"  → {inserted:,} rows inserted (replace strategy).")
        else:
            inserted = upsert_target_data(tgt_conn, rows)

        tgt_conn.commit()
        logger.info(f"SYNC COMPLETE  |  {inserted:,} rows synced for d_date={d_date}")

    except Exception as e:
        logger.error(f"Error during sync: {e}", exc_info=True)
        if tgt_conn:
            tgt_conn.rollback()
            logger.info("Target transaction rolled back.")
        raise

    finally:
        if src_conn:
            src_conn.close()
        if tgt_conn:
            tgt_conn.close()


def get_available_d_dates(source: bool = True) -> list[str]:
    """
    List all distinct d_dates available in the source (or target) table.
    Useful for backfill or validation.
    """
    config = DB_SOURCE if source else DB_TARGET
    table  = SOURCE_TABLE if source else TARGET_TABLE
    conn   = get_connection(config)
    try:
        with conn.cursor() as cur:
            cur.execute(f"SELECT DISTINCT d_date FROM {table} ORDER BY d_date DESC")
            return [str(row[0]) for row in cur.fetchall()]
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# CLI Entry Point
# ---------------------------------------------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Sync CVM campaign summary data from Database A to B by d_date."
    )
    parser.add_argument(
        "--date",
        type=str,
        default=str(date.today()),
        help="d_date to sync (YYYY-MM-DD). Defaults to today.",
    )
    parser.add_argument(
        "--strategy",
        choices=["upsert", "replace"],
        default="upsert",
        help=(
            "upsert: INSERT ... ON CONFLICT DO UPDATE (default)\n"
            "replace: DELETE existing rows for the date, then INSERT"
        ),
    )
    parser.add_argument(
        "--list-dates",
        action="store_true",
        help="List all available d_dates in the source table and exit.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    if args.list_dates:
        logger.info("Fetching available d_dates from source ...")
        dates = get_available_d_dates(source=True)
        print("\nAvailable d_dates in source:")
        for d in dates:
            print(f"  {d}")
        sys.exit(0)

    sync_by_d_date(d_date=args.date, strategy=args.strategy)