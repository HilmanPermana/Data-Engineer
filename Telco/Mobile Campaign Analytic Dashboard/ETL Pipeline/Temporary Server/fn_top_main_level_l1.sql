-- DROP FUNCTION cvm_data.fn_top_main_level_l1(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_top_main_level_l1(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

DELETE FROM cvm_data.top_main_level_l1
WHERE strmonth = p_strmonth;

WITH 

-- =========================
-- MAX EXTRACT DATE (1x only)
-- =========================
max_dt AS (
    SELECT MAX(extract_date) AS extract_date
    FROM hadoop_cvm.source_cvm_campaign_summary
    WHERE strmonth = p_strmonth
),

-- =========================
-- BASE
-- =========================
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
	OR (t.extract_date - interval '2 day')::date = m.extract_date)
    WHERE strmonth = p_strmonth
),

-- =========================
-- TARGET
-- =========================
t_target AS (
    SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
		COALESCE(campaign_initiatives,'ALL') initiatives,
        SUM(msisdn_wl) total_target
    FROM base_summary a
    JOIN wl_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
		(strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END, campaign_initiatives)
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
		COALESCE(campaign_initiatives,'ALL') initiatives,
		SUM(msisdn_delivered) as delivered,
        100 * SUM(msisdn_delivered) / NULLIF(SUM(msisdn_wl),0) delivery_rate
    FROM base_summary a
    JOIN wl_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
		(strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END, campaign_initiatives)
    )
),

-- =========================
-- ALL TAKER KPI (JOIN SEKALI)
-- =========================
t_taker_kpi AS (
    SELECT
        strmonth,
        COALESCE(tower,'ALL') tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) wltype,
		COALESCE(campaign_initiatives,'ALL') initiatives,
        SUM(total_msisdn) total_uni_taker,
        SUM(revenue) total_revenue,
		SUM(trx) total_transaction,
		(SUM(revenue)/SUM(total_msisdn)) rev_taker,
		(SUM(revenue)/SUM(trx)) rev_trx,
		(SUM(trx)/SUM(total_msisdn)) trx_taker
    FROM base_summary a
    JOIN taker_data b USING (strmonth, offer_id)
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
		(strmonth,tower, CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END, campaign_initiatives)
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
		COALESCE(campaign_initiatives,'ALL') initiatives,
        AVG(tur) tur
    FROM hadoop_cvm.tur_formulation
    WHERE strmonth = p_strmonth
      AND tower IN ('SIMPATI','HALO','AREA')
    GROUP BY GROUPING SETS (
        (strmonth),
        (strmonth,tower),
        (strmonth,wltype),
        (strmonth,tower,wltype),
		(strmonth,tower,wltype,campaign_initiatives)
    )
)

-- =========================
-- FINAL
-- =========================
INSERT INTO cvm_data.top_main_level_l1
SELECT 
    a.strmonth,
    a.tower,
    a.wltype,
	a.initiatives,
    a.total_target,
	d.total_revenue,
	d.total_transaction,
	d.total_uni_taker,
    e.tur,
	d.rev_taker,
	d.rev_trx,
	d.trx_taker,
	c.delivery_rate,
	c.delivered
FROM t_target a
LEFT JOIN delivery c USING (strmonth,tower,wltype, initiatives)
LEFT JOIN t_taker_kpi d USING (strmonth,tower,wltype, initiatives)
LEFT JOIN tur e USING (strmonth,tower,wltype, initiatives);
END;
$function$
;
