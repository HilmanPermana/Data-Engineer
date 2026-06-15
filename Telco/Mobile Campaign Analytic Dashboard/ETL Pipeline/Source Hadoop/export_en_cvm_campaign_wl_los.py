import argparse
import os
import pandas as pd
from pyspark.sql import SparkSession
from datetime import datetime, timedelta

parser = argparse.ArgumentParser()
parser.add_argument("--output_file", required=True)
parser.add_argument("--queue", default="root.mkt.hui_mkt_rna_ops")
args = parser.parse_args()

output_file = args.output_file
queue = args.queue

# =========================
# DATE LOGIC
# =========================

# tanggal sekarang (extract_date)
extract_date = datetime.today()

# d-2
d_date = extract_date - timedelta(days=2)

# ambil awal bulan dari d_date
strmonth = d_date.replace(day=1)

# format string
extract_date_str = extract_date.strftime("%Y-%m-%d")
d_date_str = d_date.strftime("%Y-%m-%d")
strmonth_str = strmonth.strftime("%Y-%m-%d")

print("extract_date :", extract_date_str)
print("d_date       :", d_date_str)
print("strmonth     :", strmonth_str)

# =========================
# SPARK SESSION
# =========================

spark = SparkSession.builder \
    .appName("export_en_cvm_campaign_summary") \
    .config("spark.yarn.queue", queue) \
    .enableHiveSupport() \
    .getOrCreate()

# =========================
# QUERY
# =========================

query = f"""
WITH wl AS
(
    SELECT
        strmonth,
        offer_id,
        msisdn_wl,
        msisdn_delivered
    FROM mkt_cm.en_cvm_campaign_wl
    WHERE strmonth='{strmonth_str}'
    AND offer_id IS NOT NULL
),

wl_distinct AS
(
    SELECT
        strmonth,
        offer_id,
        msisdn_wl,
        MAX(msisdn_delivered) msisdn_delivered
    FROM wl
    GROUP BY
        strmonth,
        offer_id,
        msisdn_wl
),

multidim AS
(
    SELECT
        msisdn,
        los
    FROM cb.cb_multidim
    WHERE event_date='{strmonth_str}'
)

select distinct 
    DATE('{extract_date_str}') AS extract_date,
    DATE('{d_date_str}') AS d_date,
    a.strmonth,
    a.offer_id,
    b.los,
    COUNT(*) total_msisdn,
    COUNT(a.msisdn_delivered) msisdn_delivered
FROM wl_distinct a
LEFT JOIN multidim b
ON a.msisdn_wl = b.msisdn
GROUP BY
    a.strmonth,
    a.offer_id,
    b.los
"""

print("Executing query...")

df = spark.sql(query)

print("Collecting to driver...")

pdf = df.toPandas()

print(f"Writing to {output_file}")

os.makedirs(os.path.dirname(output_file), exist_ok=True)

pdf.to_csv(output_file, index=False)

spark.stop()

print("SUCCESS")
