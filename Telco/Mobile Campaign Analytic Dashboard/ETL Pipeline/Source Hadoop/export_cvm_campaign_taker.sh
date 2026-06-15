#!/bin/bash
set -eo pipefail
set -u

# =========================
# Parameter
# =========================

run_date=${1:-$(date "+%Y-%m-%d")}
run_date=$(date -d "$run_date" "+%Y-%m-%d")
echo "run_date: $run_date"

data_date=$(date -d "$run_date -2 days" "+%Y-%m-%d")
echo "data_date: $data_date"

date_strmonth=$(date -d "$(date -d "$run_date -2 days" "+%Y-%m")-01" "+%Y-%m-%d")
echo "date_strmonth: $date_strmonth"

date_multidim=$(date -d "$(date -d "$run_date" "+%Y-%m-01") -1 day" "+%Y-%m-%d")
echo "date_multidim: $date_multidim"

queue_name=${2:-"root.mkt.hui_mkt_rna_ops"}
echo "queue_name: $queue_name"

script_name="$(basename "$0")"

export_dir="/data/gd_mkt_rna_ops/cvm_ops/data_collection"

mkdir -p "${export_dir}"

# =========================
# Function: run_hive
# =========================

run_hive() {

SQL="${1}"

PORT=${PORT_JDBC_HIVE:-10001}
PLATFORM="platform:${PLATFORM_RUN:-}"
SCRIPT="script:${script_name}"

beeline -u "command beeline"

}

# =========================
# Query
# =========================

query_export="
SELECT /*+ MAPJOIN(b) */
    '${run_date}' AS extract_date,
    '${data_date}' AS data_date,
    strmonth,
    'ALL' as tower_name,
    COUNT(DISTINCT msisdn) AS total_msisdn,
    SUM(trx) AS trx,
    SUM(revenue) AS revenue
FROM mkt_cm.id_cvm_campaign_taker 
WHERE strmonth='${date_strmonth}'
AND tower_name in ('SIMPATI','HALO','AREA')
AND offer_id IS NOT NULL
GROUP BY 
    strmonth  
    union all
SELECT /*+ MAPJOIN(b) */
    '${run_date}' AS extract_date,
    '${data_date}' AS data_date,
    strmonth,
    tower_name,
    COUNT(DISTINCT msisdn) AS total_msisdn,
    SUM(trx) AS trx,
    SUM(revenue) AS revenue
FROM mkt_cm.id_cvm_campaign_taker 
WHERE strmonth='${date_strmonth}'
AND tower_name in ('SIMPATI','HALO','AREA')
AND offer_id IS NOT NULL
GROUP BY 
    strmonth,
    tower_name       

"

# =========================
# Export
# =========================

export_file="${export_dir}/cvm_taker_alltower_${data_date}.csv"

echo "Start export..."

# header manual
echo "extract_date,data_date,strmonth,tower_name,total_msisdn,trx,revenue" > "${export_file}"

# export data
run_hive "${query_export}" >> "${export_file}"

echo "DONE"
echo "Output file: ${export_file}"

ls -lh "${export_file}"