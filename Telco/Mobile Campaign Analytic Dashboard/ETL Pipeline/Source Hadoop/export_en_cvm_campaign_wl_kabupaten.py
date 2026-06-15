import argparse
import os
import pandas as pd
from pyspark.sql import SparkSession

parser = argparse.ArgumentParser()
parser.add_argument("--run_date", required=True)
parser.add_argument("--output_file", required=True)
parser.add_argument("--queue", default="root.mkt.hui_mkt_rna_ops")
args = parser.parse_args()

run_date = args.run_date
output_file = args.output_file
queue = args.queue

spark = SparkSession.builder \
    .appName("export_en_cvm_campaign_wl_kabupaten") \
    .config("spark.yarn.queue", queue) \
    .enableHiveSupport() \
    .getOrCreate()

query = f"""
WITH wl AS
(
    SELECT
        strmonth,
        offer_id,
        msisdn_wl,
        msisdn_delivered
    FROM mkt_cm.en_cvm_campaign_wl
    WHERE strmonth='2026-03-01'
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
        kabupaten
    FROM cb.cb_multidim
    WHERE event_date='2026-02-25'
)

SELECT
    a.strmonth,
    a.offer_id,
    b.kabupaten,
    COUNT(*) total_msisdn,
    COUNT(a.msisdn_delivered) msisdn_delivered
FROM wl_distinct a
LEFT JOIN multidim b
ON a.msisdn_wl = b.msisdn
GROUP BY
    a.strmonth,
    a.offer_id,
    b.kabupaten
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
