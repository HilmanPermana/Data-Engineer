#!/usr/bin/env bash
set -euo pipefail

#Get Date Today
DATE=$(date +%Y-%m-01)

# Path to credentials file
CRED_FILE="/home/big/db_credentials/db_204.sh"

# Ensure credentials file exists and is not world-readable
if [[ ! -f "$CRED_FILE" ]]; then
  echo "Credentials file not found: $CRED_FILE" >&2
  exit 1
fi

source "$CRED_FILE"

FUNCTIONS=(
  "cvm_data.fn_load_tur_formulation"
  "cvm_data.fn_summary_channel"
  "cvm_data.fn_summary_channel_mtd"
  "cvm_data.fn_top_main_level"
  "cvm_data.fn_top_main_level_mtd"
  "cvm_data.fn_top_main_level_l1"
  "cvm_data.fn_top_main_level_l1_mtd"
  "cvm_data.fn_summary_product"
  "cvm_data.fn_summary_product_mtd"
  "cvm_data.fn_border_taker_init"
  "cvm_data.fn_border_wl_init"
  "cvm_data.fn_border_taker_mtd_init"
  "cvm_data.fn_border_wl_mtd_init"
)

for fn in "${FUNCTIONS[@]}"; do
	echo "Running $fn('$DATE')..."
	psql -v ON_ERROR_STOP=1 --no-align --tuples-only \
  	-h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
  	-c "SELECT $fn('$DATE');"
done 
