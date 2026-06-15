-- DROP FUNCTION cvm_data.fn_top_main_level_mtd(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_top_main_level_mtd(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

DELETE FROM cvm_data.top_main_level_mtd
WHERE strmonth = p_strmonth and d_date = 
(	
	SELECT MAX(d_date)
 	FROM hadoop_cvm.source_cvm_campaign_summary
	WHERE strmonth = p_strmonth
);

WITH 

-- =========================
-- MAX EXTRACT DATE (1x only)
-- =========================
max_dt AS (
    SELECT MAX((extract_date -interval '2 day')::date) AS extract_date
    FROM hadoop_cvm.source_cvm_campaign_summary
    WHERE strmonth = p_strmonth
),

-- =========================
-- BASE
-- =========================
base_summary AS (
    SELECT *
    FROM hadoop_cvm.source_cvm_campaign_summary w
	JOIN max_dt m ON (w.extract_date - interval '2 day')::date = m.extract_date
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
    JOIN max_dt m ON t.extract_date = m.extract_date
    WHERE strmonth = p_strmonth
),

-- =========================
-- TARGET
-- =========================
t_target AS (
    SELECT 
		a.d_date,
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
        SUM(msisdn_wl) total_target
    FROM base_summary a
    JOIN wl_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (a.d_date,strmonth),
        (a.d_date,strmonth,tower),
        (a.d_date,strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (a.d_date,strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- DELIVERY
-- =========================
delivery AS (
    SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
        100 * SUM(msisdn_delivered) / NULLIF(SUM(msisdn_wl),0) delivery_rate
    FROM base_summary a
    JOIN wl_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- TAKER & REVENUE (JOIN SEKALI)
-- =========================
t_taker_rev AS (
    SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
        SUM(total_msisdn) total_taker,
        SUM(revenue) total_revenue
    FROM base_summary a
    JOIN taker_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- CAMPAIGN
-- =========================
t_campaign AS (
    SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
        COUNT(DISTINCT offer_id) total_campaign
    FROM base_summary
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- TUR
-- =========================
tur AS (
    SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(wltype,'ALL') wltype,
        AVG(tur) tur
    FROM hadoop_cvm.tur_formulation
    WHERE strmonth = p_strmonth
      AND tower IN ('SIMPATI','HALO','AREA')
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth,wltype),
        (strmonth,tower,wltype)
    )
),

-- =========================
-- TRACKABLE
-- =========================
trackable AS (
	SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
       	100 * (COUNT(b.offer_id)::numeric / NULLIF(COUNT(a.offer_id),0)::numeric) trackable
    FROM base_summary a
    LEFT JOIN taker_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
)

-- =========================
-- FINAL
-- =========================
INSERT INTO cvm_data.top_main_level_mtd
SELECT 
	a.d_date,
    a.strmonth,
    a.tower,
    a.wltype,
    a.total_target,
    b.total_campaign,
    c.delivery_rate,
    d.total_taker,
    d.total_revenue,
    e.tur,
	f.trackable
FROM t_target a
LEFT JOIN t_campaign b USING (strmonth,tower,wltype)
LEFT JOIN delivery c USING (strmonth,tower,wltype)
LEFT JOIN t_taker_rev d USING (strmonth,tower,wltype)
LEFT JOIN tur e USING (strmonth,tower,wltype)
LEFT JOIN trackable f USING (strmonth,tower,wltype);

END;
$function$
;
