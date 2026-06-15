-- DROP FUNCTION cvm_data.fn_load_tur_formulation(date);

CREATE OR REPLACE FUNCTION cvm_data.fn_load_tur_formulation(p_strmonth date)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

-- =========================
-- DELETE EXISTING DATA
-- =========================
DELETE FROM hadoop_cvm.tur_formulation
WHERE strmonth = p_strmonth;

-- =========================
-- INSERT NEW DATA
-- =========================
WITH max_dt AS (
    SELECT MAX(d_date) AS d_date
    FROM hadoop_cvm.source_cvm_campaign_summary
    WHERE strmonth = p_strmonth
),

base_campaign AS (
    SELECT s.d_date,
        offer_id, 
        campaign_id, 
        strmonth, 
        tower, 
        TRIM(campaign_initiatives) AS campaign_initiatives,
        start_date, 
        end_date, 
        communication_channel, 
        wltype, 
        email_user,
        COUNT(DISTINCT offer_id) AS totalcid
    FROM hadoop_cvm.source_cvm_campaign_summary s
    JOIN max_dt m 
        ON s.d_date = m.d_date
    WHERE strmonth = p_strmonth
    GROUP BY 1,2,3,4,5,6,7,8,9,10,11
),

wl_data AS (
    SELECT w.d_date,
        offer_id,
        msisdn_wl::float8 AS total_wl,
        COALESCE(NULLIF(msisdn_delivered, 0), msisdn_wl)::float8 AS delivered
    FROM hadoop_cvm.source_cvm_campaign_wl_offerid w
    JOIN max_dt m 
        ON w.d_date = m.d_date
    WHERE strmonth = p_strmonth
),

taker_data AS (
    SELECT t.data_date,
        offer_id, 
        total_msisdn::float8 AS taker, 
        trx, 
        revenue
    FROM hadoop_cvm.source_cvm_taker_offerid t
    JOIN max_dt m 
        ON (t.data_date = m.d_date 
	OR (t.data_date - interval '1 day')::date = m.d_date)
    WHERE strmonth = p_strmonth
),

final_calc AS (
    SELECT 
        a.strmonth,
        a.tower,
        a.campaign_initiatives,
        a.start_date,
        a.end_date,
        a.communication_channel,
        a.totalcid,
        b.total_wl,
        b.total_wl AS eligible_wl,
        b.delivered,
        c.taker,
        c.trx,
        c.revenue AS rev,
        a.offer_id,
        a.campaign_id,
        CASE 
            WHEN a.wltype ILIKE '%rulebased%' THEN 'RULEBASED'
            ELSE 'REGULER'
        END AS wltype,
        a.email_user,

        CASE 
            WHEN c.taker > 0 AND b.delivered > 0 AND b.delivered > c.taker 
                THEN c.taker / b.delivered
            WHEN c.taker > 0 AND b.delivered > 0 AND b.delivered < c.taker 
                THEN c.taker / b.total_wl
        END AS tur,
		a.d_date
    FROM base_campaign a
    LEFT JOIN wl_data b ON a.offer_id = b.offer_id
    LEFT JOIN taker_data c ON a.offer_id = c.offer_id
)

INSERT INTO hadoop_cvm.tur_formulation
SELECT 
    strmonth,
    tower,
    campaign_initiatives,
    start_date,
    end_date,
    communication_channel,
    totalcid,
    total_wl,
    eligible_wl,
    delivered,
    taker,
    trx,
    rev,
    offer_id,
    campaign_id,
    wltype,
    email_user,
    CASE 
        WHEN tur >= 0.3 THEN 0.01 
        ELSE tur 
    END AS tur,
	d_date
FROM final_calc;

END;
$function$
;
