-- DROP FUNCTION cvm_data.fn_summary_product_mtd(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_summary_product_mtd(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

-- =========================
-- DELETE
-- =========================
DELETE FROM cvm_data.summary_product_mtd
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
    SELECT MAX((extract_date - interval '2 day')::date) AS extract_date
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
select
	a.d_date,
	a.strmonth,
	a.product as product,
	COALESCE(a.tower, 'ALL') as tower,
	COALESCE(
            CASE 
                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
                ELSE 'REGULER' 
            END,
            'ALL'
    ) AS wltype,	
	sum(msisdn_wl) as total_target
from
	base_summary a
	join wl_data b on
	a.strmonth = b.strmonth
	and a.offer_id = b.offer_id
where
	a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA')
group by grouping sets (
	(a.d_date, a.strmonth, a.product),
	(a.d_date, a.strmonth, a.product, a.tower),
	(a.d_date, a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.d_date, a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
),

-- =========================
-- STEP 2 (TAKER)
-- =========================
step2 AS (
select
	a.strmonth,
	a.product,
	COALESCE(a.tower, 'ALL') as tower,
	COALESCE(
            CASE 
                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
                ELSE 'REGULER' 
            END,
            'ALL'
    ) AS wltype,	
	sum(total_msisdn) as taker,
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
group by grouping sets (
	(a.d_date, a.strmonth, a.product),
	(a.d_date, a.strmonth, a.product, a.tower),
	(a.d_date, a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.d_date, a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
),

-- =========================
-- TUR
-- =========================
tur AS (
	select
	a.strmonth,
	a.product,
	COALESCE(a.tower, 'ALL') as tower,
	COALESCE(
            CASE 
                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
                ELSE 'REGULER' 
            END,
            'ALL'
    ) AS wltype,	
	avg(tur) as tur
from
	base_summary a
	join
	hadoop_cvm.tur_formulation b
	on a.strmonth = b.strmonth and a.offer_id = b.offer_id	
	where a.tower in ('SIMPATI','HALO','AREA') and a.strmonth = p_strmonth
group by grouping sets (
	(a.d_date, a.strmonth, a.product),
	(a.d_date, a.strmonth, a.product, a.tower),
	(a.d_date, a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.d_date, a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
),

cost as (
select 
strmonth,product,tower,wltype,sum(case when communication_channel = 'SMS' then msisdn_delivered * 262 
when communication_channel = 'WABA' then msisdn_delivered * 100 end) as cost
from (
select
	a.strmonth,
	a.product,
	COALESCE(a.tower, 'ALL') as tower,
	COALESCE(
            CASE 
                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
                ELSE 'REGULER' 
            END,
            'ALL'
    ) AS wltype,		
	a.communication_channel,
	sum(case when msisdn_delivered = 0 then msisdn_wl else msisdn_delivered end) as msisdn_delivered
from
	base_summary a
	join
wl_data b
on
	a.strmonth = b.strmonth
	and a.offer_id = b.offer_id
where
	a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA') and communication_channel in ('WABA','SMS')
group by grouping sets (
	(a.d_date, a.strmonth, a.product, a.communication_channel),
	(a.d_date, a.strmonth, a.product, a.communication_channel, a.tower),
	(a.d_date, a.strmonth, a.product, a.communication_channel, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.d_date, a.strmonth, a.product, a.communication_channel, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
)cs where communication_channel in ('WABA','SMS')
group by strmonth,product,tower,wltype
),

delivery as (
select
	a.strmonth,
	a.product,
	COALESCE(a.tower, 'ALL') as tower,
	COALESCE(
            CASE 
                WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' 
                ELSE 'REGULER' 
            END,
            'ALL'
    ) AS wltype,			
	100*(sum(msisdn_delivered) /sum(msisdn_wl)) as delivery_rate
from
	base_summary a
	join
wl_data b
on
	a.strmonth = b.strmonth
	and a.offer_id = b.offer_id
where
	a.strmonth = p_strmonth and a.tower in ('SIMPATI','HALO','AREA')
group by grouping sets (
	(a.d_date, a.strmonth, a.product),
	(a.d_date, a.strmonth, a.product, a.tower),
	(a.d_date, a.strmonth, a.product, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END),
	(a.d_date, a.strmonth, a.product, a.tower, CASE WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED' ELSE 'REGULER' END)
)
)


INSERT INTO cvm_data.summary_product_mtd
select 
a.d_date,
a.strmonth,
a.product,
a.tower,
a.wltype,
a.total_target,
c.tur,
b.revenue,
d.cost,
e.delivery_rate
from step1 a join step2 b
on  a.strmonth = b.strmonth and a.product = b.product and a.tower = b.tower and a.wltype = b.wltype
join tur c
on  a.strmonth = c.strmonth and a.product = c.product and a.tower = c.tower and a.wltype = c.wltype
join cost d
on  a.strmonth = d.strmonth and a.product = d.product and a.tower = d.tower and a.wltype = d.wltype
join delivery e
on  a.strmonth = e.strmonth and a.product = e.product and a.tower = e.tower and a.wltype = e.wltype;


END;
$function$
;
