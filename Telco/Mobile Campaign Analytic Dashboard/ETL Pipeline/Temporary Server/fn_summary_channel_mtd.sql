-- DROP FUNCTION cvm_data.fn_summary_channel_mtd(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_summary_channel_mtd(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

-- =========================
-- DELETE
-- =========================
DELETE FROM cvm_data.summary_channel_mtd
WHERE strmonth = p_strmonth and d_date = 
(	
	SELECT MAX(d_date)
 	FROM hadoop_cvm.source_cvm_campaign_summary
	WHERE strmonth = p_strmonth
);

-- =========================
-- INSERT
-- =========================
WITH 

max_dt AS (
    SELECT MAX((extract_date -interval '2 day')::date) AS extract_date
    FROM hadoop_cvm.source_cvm_campaign_summary
    WHERE strmonth = p_strmonth
),

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
-- STEP 1 (TARGET)
-- =========================
step1 AS (
    SELECT
		a.d_date,
        a.strmonth,
        COALESCE(a.tower, 'ALL') AS tower,
        COALESCE(
            CASE 
                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
                ELSE 'REGULER' 
            END,
            'ALL'
        ) AS wltype,
        COALESCE(a.communication_channel, 'ALL') AS communication_channel,
        SUM(b.msisdn_wl) AS total_target
    FROM base_summary a
    JOIN wl_data b 
        ON a.strmonth = b.strmonth 
       AND a.offer_id = b.offer_id
    GROUP BY GROUPING SETS (
        (a.d_date,a.strmonth, COALESCE(a.communication_channel,'ALL')),
        (a.d_date,a.strmonth, COALESCE(a.communication_channel,'ALL'),
            CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (a.d_date,a.strmonth, a.tower, COALESCE(a.communication_channel,'ALL')),
        (a.d_date,a.strmonth, a.tower, COALESCE(a.communication_channel,'ALL'),
            CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- STEP 2 (TAKER)
-- =========================
step2 AS (
    SELECT
        a.strmonth,
        COALESCE(a.tower, 'ALL') AS tower,
        COALESCE(
            CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) AS wltype,
        COALESCE(a.communication_channel,'ALL') as communication_channel,
        SUM(b.total_msisdn) AS taker,
        SUM(b.trx) AS trx,
        SUM(b.revenue) AS revenue
    FROM base_summary a
    JOIN taker_data b 
        ON a.strmonth = b.strmonth AND a.offer_id = b.offer_id
    GROUP BY GROUPING SETS (
        (a.strmonth, COALESCE(a.communication_channel,'ALL')),
        (a.strmonth, COALESCE(a.communication_channel,'ALL'), 
            CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (a.strmonth, a.tower, COALESCE(a.communication_channel,'ALL')),
        (a.strmonth, a.tower, COALESCE(a.communication_channel,'ALL'), 
            CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- TUR
-- =========================
tur AS (
    SELECT
        strmonth,
        COALESCE(tower, 'ALL') AS tower,
        COALESCE(
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END,
            'ALL'
        ) AS wltype,
        COALESCE(communication_channel,'ALL') as communication_channel,
        AVG(tur) AS tur
    FROM hadoop_cvm.tur_formulation
    WHERE strmonth = p_strmonth
      AND tower IN ('SIMPATI','HALO','AREA')
    GROUP BY GROUPING SETS (
        (strmonth, COALESCE(communication_channel,'ALL')),
        (strmonth, COALESCE(communication_channel,'ALL'), 
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
        (strmonth, tower, COALESCE(communication_channel,'ALL')),
        (strmonth, tower, COALESCE(communication_channel,'ALL'), 
            CASE WHEN wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
    )
),

-- =========================
-- FINAL JOIN
-- =========================
final AS (
    SELECT 
        a.*,
        b.taker,
        b.trx,
        c.tur,
        b.revenue
    FROM step1 a
    LEFT JOIN step2 b USING (strmonth, tower, wltype, communication_channel)
    LEFT JOIN tur c USING (strmonth, tower, wltype, communication_channel)
)

INSERT INTO cvm_data.summary_channel_mtd
SELECT 
	d_date,
    strmonth,
    tower,
    wltype,
    communication_channel,
    total_target,
    taker,
    trx,
    tur,
    revenue,
    revenue / NULLIF(taker,0),
    revenue / NULLIF(trx,0),
    trx / NULLIF(taker,0)
FROM final;

END;
$function$
;
