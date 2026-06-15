#!/bin/bash

# ======================================================
# EXPORT ICEBERG TABLE VIA BEELINE
# SAFE FOR RANGER + ICEBERG + SECURE CLUSTER
# ======================================================

set -eo pipefail

# ======================================================
# KINIT (Kerberos auth)
# ======================================================

sh /home/cvm_ops/script/kinit.sh

# ======================================================
# PARAMETER
# ======================================================

RUN_DATE=${1:-$(date "+%Y-%m-%d")}

OUTPUT_DIR="/home/cvm_ops/data_collection"
OUTPUT_FILE="${OUTPUT_DIR}/en_cvm_campaign_summary_${RUN_DATE}.csv"

LOG_FILE="${OUTPUT_DIR}/export_en_cvm_campaign_summary_${RUN_DATE}.log"

mkdir -p "$OUTPUT_DIR"

echo "========================================" | tee -a "$LOG_FILE"
echo "START EXPORT: $(date)" | tee -a "$LOG_FILE"
echo "TABLE       : mkt_cm.en_cvm_campaign_summary" | tee -a "$LOG_FILE"
echo "RUN_DATE    : $RUN_DATE" | tee -a "$LOG_FILE"
echo "OUTPUT FILE : $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# ======================================================
# BEELINE CONNECTION STRING
# ======================================================

BEELINE_URL=""

# ======================================================
# EXPORT QUERY
# ======================================================

beeline \
-u "$BEELINE_URL" \
--silent=true \
--showHeader=true \
--outputformat=csv2 \
-e "
SELECT
    strmonth,
    offer_id,
    campaign_id,
    tower,
    product,
    regexp_replace(campaign_initiatives, '[\\r\\n\\t]', ' ') AS campaign_initiatives,
    start_date,
    end_date,
    communication_channel,
    id_campaign_objective,
    id_campaign_category,
    camp_category,
    wltype,
    sender_initial_bc,
    regexp_replace(email_user, '[\\r\\n\\t]', ' ') AS email_user,
    date_initial_bc,
    catcamp
FROM mkt_cm.en_cvm_campaign_summary
WHERE strmonth ='${RUN_DATE}'  
" \
> "$OUTPUT_FILE"

# ======================================================
# VALIDATE RESULT
# ======================================================

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "ERROR: Output file empty or failed" | tee -a "$LOG_FILE"
    exit 1
fi

echo "========================================" | tee -a "$LOG_FILE"
echo "EXPORT SUCCESS: $(date)" | tee -a "$LOG_FILE"
echo "FILE CREATED  : $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
