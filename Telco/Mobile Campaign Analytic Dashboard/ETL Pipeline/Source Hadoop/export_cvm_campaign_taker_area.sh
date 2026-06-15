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
SELECT 'kabupaten' as level,
    '${run_date}' AS extract_date,
    '${data_date}' AS data_date,
    a.strmonth,
    a.offer_id,
    b.kabupaten as border,
    COUNT(DISTINCT a.msisdn) AS total_msisdn,
    SUM(a.trx) AS trx,
    SUM(a.revenue) AS revenue
FROM mkt_cm.id_cvm_campaign_taker a
LEFT JOIN cb.cb_multidim b
ON a.msisdn = b.msisdn
AND b.event_date='${date_multidim}'
WHERE a.strmonth='${date_strmonth}'
AND a.offer_id IS NOT NULL
GROUP BY 
    a.strmonth,
    a.offer_id,
    b.kabupaten  
	
union all

SELECT 'area_sales' as level,
    '${run_date}' AS extract_date,
    '${data_date}' AS data_date,
    a.strmonth,
    a.offer_id,
    b.area_sales as border,
    COUNT(DISTINCT a.msisdn) AS total_msisdn,
    SUM(a.trx) AS trx,
    SUM(a.revenue) AS revenue
FROM mkt_cm.id_cvm_campaign_taker a
LEFT JOIN cb.cb_multidim b
ON a.msisdn = b.msisdn
AND b.event_date='${date_multidim}'
WHERE a.strmonth='${date_strmonth}'
AND a.offer_id IS NOT NULL
GROUP BY 
    a.strmonth,
    a.offer_id,
    b.area_sales  	
	
union all

SELECT 'region_sales' as level,
    '${run_date}' AS extract_date,
    '${data_date}' AS data_date,
    a.strmonth,
    a.offer_id,
    b.region_sales as border,
    COUNT(DISTINCT a.msisdn) AS total_msisdn,
    SUM(a.trx) AS trx,
    SUM(a.revenue) AS revenue
FROM mkt_cm.id_cvm_campaign_taker a
LEFT JOIN cb.cb_multidim b
ON a.msisdn = b.msisdn
AND b.event_date='${date_multidim}'
WHERE a.strmonth='${date_strmonth}'
AND a.offer_id IS NOT NULL
GROUP BY 
    a.strmonth,
    a.offer_id,
    b.region_sales  	  
"

# =========================
# Export
# =========================

export_file="${export_dir}/cvm_taker_border_${run_date}.csv"

echo "Start export..."

# header manual
echo "level,extract_date,data_date,strmonth,offer_id,border,total_msisdn,trx,revenue" > "${export_file}"

# export data
run_hive "${query_export}" >> "${export_file}"

echo "DONE"
echo "Output file: ${export_file}"

ls -lh "${export_file}"