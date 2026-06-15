#!/bin/bash

RUN_DATE=$1

OUTPUT="/data/gd_mkt_rna_ops/cvm_ops/data_collection/wl_offerid_${RUN_DATE}"

spark-submit \
--master yarn \
--deploy-mode client \
export_cvm_campaign_wl_offerid.py \
--run_date "$RUN_DATE" \
--output_path "$OUTPUT"

echo "DONE: $RUN_DATE"