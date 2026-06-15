#!/bin/bash
set -e

# =========================
# DATE (AUTO)
# =========================
RUN_DATE=$(date "+2026-05-01")

OUTPUT_FILE="/data/gd_mkt_rna_ops/cvm_ops/data_collection/en_cvm_campaign_wl_los_${RUN_DATE}.csv"

echo "========================="
echo "RUN DATE: $RUN_DATE"
echo "OUTPUT  : $OUTPUT_FILE"
echo "========================="

# =========================
# RUN SPARK JOB
# =========================
spark-submit \
--master yarn \
--deploy-mode client \
--queue root.mkt.hui_mkt_rna_ops \
export_en_cvm_campaign_wl_los.py \
--output_file "$OUTPUT_FILE"

echo "========================="
echo "CSV SUCCESS 🚀"
echo "========================="
