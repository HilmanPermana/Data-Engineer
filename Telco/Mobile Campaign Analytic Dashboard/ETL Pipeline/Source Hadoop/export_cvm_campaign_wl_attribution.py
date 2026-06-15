import argparse
from pyspark.sql import SparkSession

# -------------------------
# ARGUMENT
# -------------------------
parser = argparse.ArgumentParser()
parser.add_argument("--run_date", required=True)
parser.add_argument("--output_path", required=True)
parser.add_argument("--queue", default="root.mkt.hui_mkt_rna_ops")

args = parser.parse_args()

run_date = args.run_date
output_path = args.output_path
queue = args.queue

# -------------------------
# SPARK SESSION
# -------------------------
spark = SparkSession.builder \
    .appName("export_cvm_campaign_wl_attribution") \
    .config("spark.yarn.queue", queue) \
    .enableHiveSupport() \
    .getOrCreate()

spark.conf.set("spark.sql.shuffle.partitions", 200)
spark.conf.set("spark.sql.adaptive.enabled", "true")

print("RUN DATE:", run_date)

query = f"""
WITH base AS (

SELECT
    msisdn_wl,
    offer_id,
    MIN(start_date) AS start_date
FROM mkt_cm.en_cvm_campaign_wl
WHERE strmonth='{run_date}'
AND offer_id IS NOT NULL
GROUP BY msisdn_wl, offer_id

),

ranked AS (

SELECT
    *,
    ROW_NUMBER() OVER(
        PARTITION BY msisdn_wl
        ORDER BY start_date ASC
    ) rn
FROM base

)

SELECT
    offer_id,
    COUNT(msisdn_wl) AS total_msisdn
FROM ranked
WHERE rn = 1
GROUP BY offer_id
"""

print("Executing query...")

df = spark.sql(query)

print("ROW COUNT:", df.count())

print("Writing output...")

df.write \
  .mode("overwrite") \
  .option("header", True) \
  .csv(output_path)

spark.stop()

print("SUCCESS")