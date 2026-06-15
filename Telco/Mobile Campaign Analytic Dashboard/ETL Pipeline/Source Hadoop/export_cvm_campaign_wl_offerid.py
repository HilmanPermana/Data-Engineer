import argparse
from pyspark.sql import SparkSession
from pyspark.sql.functions import lit

parser = argparse.ArgumentParser()

parser.add_argument("--extract_date", required=True)
parser.add_argument("--data_date", required=True)
parser.add_argument("--strmonth", required=True)
parser.add_argument("--output_file", required=True)

args = parser.parse_args()

extract_date = args.extract_date
data_date = args.data_date
strmonth = args.strmonth
output_file = args.output_file

spark = SparkSession.builder \
    .appName("export_cvm_campaign_wl") \
    .enableHiveSupport() \
    .getOrCreate()

df = spark.sql(f"""
SELECT
    strmonth,
    offer_id,
    COUNT(DISTINCT msisdn) AS total_wl
FROM mkt_cm.en_cvm_campaign_wl
WHERE strmonth = '{strmonth}'
AND offer_id IS NOT NULL
GROUP BY
    strmonth,
    offer_id
""")

df = df.withColumn("extract_date", lit(extract_date)) \
       .withColumn("data_date", lit(data_date))

df.select(
    "extract_date",
    "data_date",
    "strmonth",
    "offer_id",
    "total_wl"
).coalesce(1).write \
 .mode("overwrite") \
 .option("header", True) \
 .csv(output_file)

spark.stop()