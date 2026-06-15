#!/bin/bash

RUN_DATE=${1:-$(date "+%Y-%m-%d")}

OUTPUT_FILE="/data/gd_mkt_rna_ops/cvm_ops/data_collection/en_cvm_campaign_wl_kabupaten_${RUN_DATE}.csv"

spark-submit \
--master yarn \
--deploy-mode client \
--queue root.mkt.hui_mkt_rna_ops \
export_en_cvm_campaign_wl_kabupaten.py \
--run_date "$RUN_DATE" \
--output_file "$OUTPUT_FILE"

echo "DONE: $OUTPUT_FILE"
