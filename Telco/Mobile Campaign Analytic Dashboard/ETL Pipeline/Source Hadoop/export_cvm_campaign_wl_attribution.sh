#!/bin/bash

RUN_DATE=$1

OUTPUT="/home/cvm_ops/data_collection/wl_attr_${RUN_DATE}"

spark-submit \
--master yarn \
--deploy-mode client \
export_cvm_campaign_wl_attribution.py \
--run_date "$RUN_DATE" \
--output_path "$OUTPUT"

echo "DONE: $RUN_DATE"