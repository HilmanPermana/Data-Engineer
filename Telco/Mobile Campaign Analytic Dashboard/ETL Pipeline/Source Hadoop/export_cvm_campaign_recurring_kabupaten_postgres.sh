#!/bin/bash
set -e

# =========================
# DATE (AUTO)
# =========================
RUN_DATE=$(date "+%Y-%m-%d")

CSV_FILE="/data/gd_mkt_rna_ops/cvm_ops/data_collection/en_cvm_campaign_wl_recurring_kabupaten_${RUN_DATE}.csv"

# =========================
# POSTGRES CONFIG
# =========================
PG_HOST="host"
PG_PORT="port"
PG_DB="database"
PG_USER="user"
PG_SCHEMA="hadoop_cvm"


export PGPASSWORD="password"

PG_TABLE="${PG_SCHEMA}.source_en_cvm_campaign_wl_recurring_kabupaten"
TEMP_TABLE="${PG_SCHEMA}.temp_en_cvm_campaign_wl_recurring_kabupaten"


echo "========================="
echo "LOAD CSV TO POSTGRES"
echo "RUN DATE : $RUN_DATE"
echo "CSV FILE : $CSV_FILE"
echo "========================="

# =========================
# VALIDASI FILE
# =========================
if [ ! -f "$CSV_FILE" ]; then
  echo "❌ ERROR: CSV file tidak ditemukan!"
  exit 1
fi

# =========================
# STEP 1: LOAD KE TEMP
# =========================
echo "[1/2] Load ke TEMP table..."

psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB \
-c "TRUNCATE TABLE $TEMP_TABLE;"

psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB \
-c "\COPY $TEMP_TABLE FROM '$CSV_FILE' CSV HEADER;"

echo "TEMP LOAD DONE ✅"

# =========================
# STEP 2: MERGE (REPLACE)
# =========================
echo "[2/2] Merge ke MAIN table..."

psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB <<EOF

BEGIN;

DELETE FROM $PG_TABLE
WHERE extract_date = DATE '$RUN_DATE';

INSERT INTO $PG_TABLE
SELECT * FROM $TEMP_TABLE;

COMMIT;

EOF

echo "========================="
echo "INSERT SUCCESS 🚀"
echo "========================="