#!/bin/bash
set -e

echo "START ETL $(date)"

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_summary.sh > /home/cvm_ops/logging/source_cvm_summary.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_summary_postgres.sh > /home/cvm_ops/logging/source_cvm_summary_postgres.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_wl.sh > /home/cvm_ops/logging/source_cvm_wl.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_wl_postgres.sh > /home/cvm_ops/logging/source_cvm_wl_postgres.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_wl_area.sh > /home/cvm_ops/logging/source_cvm_wl_area.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_wl_postgres_border.sh > /home/cvm_ops/logging/source_cvm_wl_postgres_border.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_wl_recurring.sh > /home/cvm_ops/logging/source_cvm_wl_recurring.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_recurring_postgres.sh > /home/cvm_ops/logging/source_cvm_wl_recurring_postgres.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_wl_recurring_kabupaten.sh > /home/cvm_ops/logging/source_cvm_wl_recurring_kabupaten.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_recurring_kabupaten_postgres.sh > /home/cvm_ops/logging/source_cvm_wl_recurring_kabupaten_postgres.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_en_cvm_campaign_wl_los.sh > /home/cvm_ops/logging/source_cvm_wl_los.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_los_postgres.sh > /home/cvm_ops/logging/source_cvm_wl_los_postgres.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_taker_offerid.sh > /home/cvm_ops/logging/source_cvm_taker_offerid.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_taker_postgres.sh > /home/cvm_ops/logging/source_cvm_taker_postgres.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_taker_area.sh > /home/cvm_ops/logging/source_cvm_taker_area.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_taker_postgres_border.sh > /home/cvm_ops/logging/source_cvm_taker_postgres_border.log 2>&1

sh /data/gd_mkt_rna_ops/cvm_ops/CVM/SCRIPT/cvm_data_collection/export_cvm_campaign_taker_los.sh > /home/cvm_ops/logging/source_cvm_taker_los.log 2>&1


echo "END ETL $(date)"
