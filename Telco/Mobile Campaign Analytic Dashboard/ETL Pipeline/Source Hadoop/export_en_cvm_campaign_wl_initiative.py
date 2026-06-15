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
    .appName("export_en_cvm_campaign_wl") \
    .config("spark.yarn.queue", queue) \
    .enableHiveSupport() \
    .getOrCreate()

query = f"""
SELECT
    strmonth,
    offer_id,
    campaign_id,
    tower,
    product,
    campaign_initiatives,
    start_date,
    end_date,
    communication_channel,
    id_campaign_objective,
    id_campaign_category,
    camp_category,
    wltype,
    sender_initial_bc,
    email_user,
    date_initial_bc,
    catcamp
FROM mkt_cm.en_cvm_campaign_summary
WHERE strmonth ='{run_date}'
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
