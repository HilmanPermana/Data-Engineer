-- DROP FUNCTION cvm_data.fn_border_taker_init(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_border_taker_init(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_dummy integer;
BEGIN

-- =========================
-- DELETE EXISTING DATA
-- =========================
DELETE FROM cvm_data.cvm_taker_border_area_init WHERE strmonth = p_strmonth;
DELETE FROM cvm_data.cvm_taker_border_region_init WHERE strmonth = p_strmonth;
DELETE FROM cvm_data.cvm_taker_border_kabupaten_init WHERE strmonth = p_strmonth;

-- =========================
-- INSERT TAKER REGION 
-- =========================
WITH 
max_dt AS (
    SELECT MAX(extract_date) AS extract_date
    FROM hadoop_cvm.source_cvm_campaign_summary
    WHERE strmonth = p_strmonth
),base_summary AS (
    SELECT *
    FROM hadoop_cvm.source_cvm_campaign_summary w
	JOIN max_dt m ON w.extract_date = m.extract_date
    WHERE strmonth = p_strmonth
      AND tower IN ('SIMPATI','HALO','AREA', 'OTHERS', 'BYU')
),taker_data AS (
    SELECT *
    FROM hadoop_cvm.source_cvm_taker_border t
    JOIN max_dt m ON (t.extract_date::date = m.extract_date
    OR '2026-05-19' = m.extract_date)
    WHERE strmonth = p_strmonth
),
-- =========================
-- TAKER
-- =========================
taker_region AS (
	select
		a.strmonth,
		b.border,
		a.campaign_initiatives,
		COALESCE(a.tower, 'ALL') as tower,
		COALESCE(
	            CASE 
	                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
	                ELSE 'REGULER' 
	            END,
	            'ALL'
	    ) AS wltype,	
		sum(total_msisdn) as unique_taker,
		sum(trx) as trx,
		sum(revenue) as revenue
	from
		base_summary a
		join
	taker_data b
	on
		a.strmonth = b.strmonth
		and a.offer_id = b.offer_id
	where
		a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA')
		and b.level = 'region_sales'
	group by grouping sets (
		(a.strmonth, b.border, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END, a.campaign_initiatives)
	)
),

taker_area AS (
	select
		a.strmonth,
		b.border,
		a.campaign_initiatives,
		COALESCE(a.tower, 'ALL') as tower,
		COALESCE(
	            CASE 
	                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
	                ELSE 'REGULER' 
	            END,
	            'ALL'
	    ) AS wltype,	
		sum(total_msisdn) as unique_taker,
		sum(trx) as trx,
		sum(revenue) as revenue
	from
		base_summary a
		join
	taker_data b
	on
		a.strmonth = b.strmonth
		and a.offer_id = b.offer_id
	where
		a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA')
		and b.level = 'area_sales'
	group by grouping sets (
		(a.strmonth, b.border, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END, a.campaign_initiatives)
	)
),

taker_kabupaten AS (
	select
		a.strmonth,
		b.border,
		a.campaign_initiatives,
		COALESCE(a.tower, 'ALL') as tower,
		COALESCE(
	            CASE 
	                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
	                ELSE 'REGULER' 
	            END,
	            'ALL'
	    ) AS wltype,	
		sum(total_msisdn) as unique_taker,
		sum(trx) as trx,
		sum(revenue) as revenue
	from
		base_summary a
		join
	taker_data b
	on
		a.strmonth = b.strmonth
		and a.offer_id = b.offer_id
	where
		a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA')
		and b.level = 'kabupaten'
	group by grouping sets (
		(a.strmonth, b.border, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END, a.campaign_initiatives)
	)
),
ins_region AS (
    INSERT INTO cvm_data.cvm_taker_border_region_init
    SELECT
        t.strmonth,
        t.border,
        t.tower,
        t.wltype,
        t.campaign_initiatives,
        t.revenue,
        t.trx,
        t.unique_taker
    FROM taker_region t
    RETURNING 1
),
ins_area AS (
    INSERT INTO cvm_data.cvm_taker_border_area_init
    SELECT
        t.strmonth,
        t.border,
        t.tower,
        t.wltype,
        t.campaign_initiatives,
        t.revenue,
        t.trx,
        t.unique_taker
    FROM taker_area t
    RETURNING 1
),
ins_kabupaten AS (
    INSERT INTO cvm_data.cvm_taker_border_kabupaten_init
    SELECT
        t.strmonth,
        t.border,
        t.tower,
        t.wltype,
        t.campaign_initiatives,
        t.revenue,
        t.trx,
        t.unique_taker
    FROM taker_kabupaten t
    RETURNING 1
)
-- Final select to make the WITH a single statement
SELECT 1 INTO v_dummy;

END;
$function$
;
