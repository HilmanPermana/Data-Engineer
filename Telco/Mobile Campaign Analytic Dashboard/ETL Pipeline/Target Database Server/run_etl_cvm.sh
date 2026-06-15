#!/bin/bash
# =============================================================================
# ETL Runner Script
# Executes multiple ETL Python scripts sequentially
# Usage:
#   ./run_etl.sh                        # run all, default today's date
#   ./run_etl.sh --date 2024-11-01      # run all with specific date
#   ./run_etl.sh --strategy replace     # run all with replace strategy
#   ./run_etl.sh --date 2024-11-01 --strategy replace
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Auto-detect Python executable (handles Windows, Linux, macOS)
if command -v python &>/dev/null && python --version 2>&1 | grep -q "Python 3"; then
    PYTHON=python
elif command -v python3 &>/dev/null; then
    PYTHON=python3
elif command -v py &>/dev/null && py --version 2>&1 | grep -q "Python 3"; then
    PYTHON="py"
else
    echo "[ERROR] Python 3 not found. Install Python 3 and ensure it is added to PATH."
    exit 1
fi

echo "Using Python executable: ${PYTHON} ($(${PYTHON} --version))"

ETL_DIR="$(cd "$(dirname "$0")" && pwd)"     # directory where this script lives
LOG_DIR="${ETL_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUNNER_LOG="${LOG_DIR}/etl_runner_${TIMESTAMP}.log"

# ---------------------------------------------------------------------------
# ETL Scripts to Execute (add or remove entries as needed)
# ---------------------------------------------------------------------------
ETL_SCRIPTS=(
    "etl_top_main_level_mtd.py"
    "etl_top_main_level_l1_mtd.py"
    "etl_summary_channel_mtd.py"
)

# ---------------------------------------------------------------------------
# Parse Arguments
# ---------------------------------------------------------------------------
DATE_ARG=""
STRATEGY_ARG=""
LIST_DATES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --date)
            DATE_ARG="--date $2"
            shift 2
            ;;
        --strategy)
            STRATEGY_ARG="--strategy $2"
            shift 2
            ;;
        --list-dates)
            LIST_DATES=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--date YYYY-MM-DD] [--strategy upsert|replace] [--list-dates]"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
mkdir -p "${LOG_DIR}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "${RUNNER_LOG}"
}

log_separator() {
    log "============================================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_separator
log "ETL RUNNER STARTED"
log "Working directory : ${ETL_DIR}"
log "Runner log        : ${RUNNER_LOG}"
log "Arguments         : ${DATE_ARG} ${STRATEGY_ARG}"
log_separator

TOTAL=${#ETL_SCRIPTS[@]}
SUCCESS=0
FAILED=0
FAILED_SCRIPTS=()

for SCRIPT in "${ETL_SCRIPTS[@]}"; do
    SCRIPT_PATH="${ETL_DIR}/${SCRIPT}"
    SCRIPT_LOG="${LOG_DIR}/${SCRIPT%.py}_${TIMESTAMP}.log"

    log ""
    log "▶ Running : ${SCRIPT}"
    log "  Script log : ${SCRIPT_LOG}"

    # Check script exists
    if [[ ! -f "${SCRIPT_PATH}" ]]; then
        log "  [SKIP] File not found: ${SCRIPT_PATH}"
        FAILED=$((FAILED + 1))
        FAILED_SCRIPTS+=("${SCRIPT} (file not found)")
        continue
    fi

    START_TIME=$(date +%s)

    # Build command as array to safely handle paths with spaces
    if $LIST_DATES; then
        CMD=("${PYTHON}" "${SCRIPT_PATH}" --list-dates)
    else
        CMD=("${PYTHON}" "${SCRIPT_PATH}")
        [[ -n "${DATE_ARG}"     ]] && CMD+=(--date     "${DATE_ARG#--date }")
        [[ -n "${STRATEGY_ARG}" ]] && CMD+=(--strategy "${STRATEGY_ARG#--strategy }")
    fi

    # Execute and capture output
    if "${CMD[@]}" 2>&1 | tee -a "${SCRIPT_LOG}" "${RUNNER_LOG}"; then
        END_TIME=$(date +%s)
        ELAPSED=$((END_TIME - START_TIME))
        log "  [OK] ${SCRIPT} completed in ${ELAPSED}s"
        SUCCESS=$((SUCCESS + 1))
    else
        END_TIME=$(date +%s)
        ELAPSED=$((END_TIME - START_TIME))
        log "  [FAILED] ${SCRIPT} failed after ${ELAPSED}s — check log: ${SCRIPT_LOG}"
        FAILED=$((FAILED + 1))
        FAILED_SCRIPTS+=("${SCRIPT}")
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log ""
log_separator
log "ETL RUNNER FINISHED"
log "  Total   : ${TOTAL}"
log "  Success : ${SUCCESS}"
log "  Failed  : ${FAILED}"
if [[ ${#FAILED_SCRIPTS[@]} -gt 0 ]]; then
    log "  Failed scripts:"
    for S in "${FAILED_SCRIPTS[@]}"; do
        log "    - ${S}"
    done
fi
log_separator

# Exit with error code if any script failed
if [[ ${FAILED} -gt 0 ]]; then
    exit 1
fi

exit 0