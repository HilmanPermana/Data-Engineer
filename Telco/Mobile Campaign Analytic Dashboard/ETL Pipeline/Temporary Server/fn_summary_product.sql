-- DROP FUNCTION cvm_data.fn_summary_product(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_summary_product(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

DELETE FROM cvm_data.summary_product
WHERE strmonth = p_strmonth;

WITH 

max_dt AS (
    SELECT MAX(extract_date) AS extract_date
    FROM hadoop_cvm.source_cvm_campaign_summary
    WHERE strmonth = p_strmonth
),

base_summary AS (
    SELECT *
    FROM hadoop_cvm.source_cvm_campaign_summary w
    JOIN max_dt m ON w.extract_date = m.extract_date
    WHERE strmonth = p_strmonth
      AND tower IN ('SIMPATI','HALO','AREA')
),

wl_data AS (
    SELECT *
    FROM hadoop_cvm.source_cvm_campaign_wl_offerid w
    JOIN max_dt m ON w.extract_date = m.extract_date
    WHERE strmonth = p_strmonth
),

taker_data AS (
    SELECT *
    FROM hadoop_cvm.source_cvm_taker_offerid t
    JOIN max_dt m ON (t.extract_date = m.extract_date
	OR (t.extract_date - interval '1 day')::date = m.extract_date)
    WHERE strmonth = p_strmonth
),

-- STEP 1 (TARGET)
step1 AS (
SELECT
    a.strmonth,
    a.product,
    COALESCE(a.tower,'ALL') AS tower,
    COALESCE(CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,'ALL') AS wltype,
    SUM(msisdn_wl) AS total_target
FROM base_summary a
JOIN wl_data b ON a.strmonth=b.strmonth AND a.offer_id=b.offer_id
GROUP BY GROUPING SETS (
   (a.strmonth, a.product),
	(a.strmonth, a.product, a.tower),
	(a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
),

-- STEP 2 (TAKER)
step2 AS (
SELECT
    a.strmonth,
    a.product,
    COALESCE(a.tower,'ALL') AS tower,
    COALESCE(CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,'ALL') AS wltype,
    SUM(total_msisdn) AS taker,
    SUM(trx) AS trx,
    SUM(revenue) AS revenue
FROM base_summary a
JOIN taker_data b ON a.strmonth=b.strmonth AND a.offer_id=b.offer_id
GROUP BY GROUPING SETS (
   (a.strmonth, a.product),
	(a.strmonth, a.product, a.tower),
	(a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
),

-- TUR
tur AS (
SELECT
    a.strmonth,
    a.product,
    COALESCE(a.tower,'ALL') AS tower,
    COALESCE(CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,'ALL') AS wltype,
    AVG(tur) AS tur
FROM base_summary a
JOIN hadoop_cvm.tur_formulation b ON a.strmonth=b.strmonth AND a.offer_id=b.offer_id
GROUP BY GROUPING SETS (
 	(a.strmonth, a.product),
	(a.strmonth, a.product, a.tower),
	(a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
),

-- COST
cost AS (
SELECT 
    strmonth, product, tower, wltype,
    SUM(CASE WHEN communication_channel='SMS' THEN msisdn_delivered*262
             WHEN communication_channel='WABA' THEN msisdn_delivered*100 END) AS cost
FROM (
    SELECT
        a.strmonth,
        a.product,
        COALESCE(a.tower,'ALL') AS tower,
        COALESCE(CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,'ALL') AS wltype,
        a.communication_channel,
        SUM(CASE WHEN msisdn_delivered=0 THEN msisdn_wl ELSE msisdn_delivered END) AS msisdn_delivered
    FROM base_summary a
    JOIN wl_data b ON a.strmonth=b.strmonth AND a.offer_id=b.offer_id
    WHERE a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA') and a.communication_channel in ('WABA','SMS')
    GROUP BY GROUPING SETS (
   (a.strmonth, a.product, a.communication_channel),
	(a.strmonth, a.product, a.communication_channel, a.tower),
	(a.strmonth, a.product, a.communication_channel, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.strmonth, a.product, a.communication_channel, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
) cs
WHERE communication_channel IN ('WABA','SMS')
GROUP BY strmonth, product, tower, wltype
),

-- DELIVERY
delivery AS (
SELECT
    a.strmonth,
    a.product,
    COALESCE(a.tower,'ALL') AS tower,
    COALESCE(CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,'ALL') AS wltype,
    100*(SUM(msisdn_delivered)/SUM(msisdn_wl)) AS delivery_rate
FROM base_summary a
JOIN wl_data b ON a.strmonth=b.strmonth AND a.offer_id=b.offer_id
GROUP BY GROUPING SETS (
   (a.strmonth, a.product),
	(a.strmonth, a.product, a.tower),
	(a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
)

INSERT INTO cvm_data.summary_product
SELECT 
    a.strmonth,
    a.product,
    a.tower,
    a.wltype,
    a.total_target,
    c.tur,
    b.revenue,
    d.cost,
    e.delivery_rate
FROM step1 a
JOIN step2 b ON a.strmonth=b.strmonth AND a.product=b.product AND a.tower=b.tower AND a.wltype=b.wltype
JOIN tur c ON a.strmonth=c.strmonth AND a.product=c.product AND a.tower=c.tower AND a.wltype=c.wltype
JOIN cost d ON a.strmonth=d.strmonth AND a.product=d.product AND a.tower=d.tower AND a.wltype=d.wltype
JOIN delivery e ON a.strmonth=e.strmonth AND a.product=e.product AND a.tower=e.tower AND a.wltype=e.wltype;


END;
$function$
;
