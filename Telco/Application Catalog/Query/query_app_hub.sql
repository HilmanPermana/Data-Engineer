select * from app_hub.get_tag_category();
select * from app_hub.get_tag_function();
select * from app_hub.get_tag_db_system();

select * from app_hub.get_application_category();
select * from app_hub.get_application_catalog(null, array[1,6]);
select * from app_hub.get_application_catalog(null, null);
select * from app_hub.get_application_catalog_review(null);
select app_hub.soft_delete_ndap_catalogue_app(9999);

select * from app_hub.application_portfolio;
select * from app_hub.application_usage;
select * from app_hub.install_type_summary;
select * from app_hub.category_manufacturer_summary;
select * from app_hub.category_version_status_summary;

select distinct manufacturer from app_hub.get_category_manufacturer_matrix();
select * from app_hub.get_category_manufacturer_matrix();

select * from app_hub.get_category_version_status_matrix();

select * from app_hub.get_top_10_by_total_active_users('category');

SELECT * FROM app_hub.get_apps_count_by_column('category');
SELECT * FROM app_hub.get_apps_count_by_column('install_type');
SELECT * FROM app_hub.get_apps_count_by_column('manufacturer');

select * from app_hub.get_filters_by_context('FILTER_TOP_10_BY_TOTAL_USER');
select * from app_hub.get_group_by_filter_for_top_10_by_total_active_users();

SELECT * FROM app_hub.filter_reference;

select * from app_hub.get_app_details_by_id(53);

UPDATE app_hub.ndap_catalogue_app
SET tag_category = 'Reporting, Analytic, ML and Visualization'
WHERE tag_category = 'Reporting, Analytic, ML & Visualization';

UPDATE app_hub.ndap_catalogue_app
SET tag_db_system = 'Database - MariaDB'
WHERE tag_db_system = 'Database - Maria DB';

INSERT INTO app_hub.tags_reference (id, tag, name) 
VALUES (997, 'category', 'Other Category');

INSERT INTO app_hub.tags_reference (id, tag, name) 
VALUES (998, 'function', 'Other Function');

INSERT INTO app_hub.tags_reference (id, tag, name) 
VALUES (999, 'db_system', 'Other DB System');

UPDATE app_hub.ndap_catalogue_app
SET tag_category = 'Other Category'
WHERE tag_category is null;

UPDATE app_hub.ndap_catalogue_app
SET tag_function_application = 'Other Function'
WHERE tag_function_application is null;

UPDATE app_hub.ndap_catalogue_app
SET tag_db_system = 'Other DB System'
WHERE tag_db_system is null;

select count(result.count) as total from (
SELECT 
        r.id as id,
        r.tag as tag,
        r.name as name,
        count(*) as count
    FROM app_hub.ndap_catalogue_app nc
    LEFT JOIN app_hub.tags_reference r ON (r.name = nc.tag_category or r.name = nc.tag_function_application or r.name = nc.tag_db_system)
    where r.tag is not null
    GROUP BY 1, 2, 3
    UNION ALL
    SELECT 
        997 as id,
        'category' as tag,
        'Other Category' as name,
        count(*) as count
    FROM app_hub.ndap_catalogue_app nc
    where nc.tag_category is null
    GROUP BY 1, 2, 3
    UNION ALL
    SELECT 
        998 as id,
        'function' as tag,
        'Other Function' as name,
        count(*) as count
    FROM app_hub.ndap_catalogue_app nc
    where nc.tag_function_application is null
    GROUP BY 1, 2, 3
    UNION ALL
    SELECT 
        999 as id,
        'db_system' as tag,
        'Other DB System' as name,
        count(*) as count
    FROM app_hub.ndap_catalogue_app nc
    where nc.tag_db_system is null
    GROUP BY 1, 2, 3
    ORDER BY 4 desc) as result

-- Function to get applications with optional keyword and tag filtering
CREATE OR REPLACE FUNCTION app_hub.get_application_catalog(search_keyword text DEFAULT NULL::text, tag_ids integer[] DEFAULT NULL::integer[])
 RETURNS TABLE(id integer, vendor_name character varying, asset_name character varying, description text, tag_category character varying, tag_function_application character varying, tag_db_system character varying, tag_category_id integer, tag_function_application_id integer, tag_db_system_id integer, is_deleted boolean, deleted_at timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.id,
        n.vendor_name,
        n.asset_name,
        n.description,
        n.tag_category,
        n.tag_function_application,
        n.tag_db_system,
        t1.id as tag_category_id,
        t2.id as tag_function_application_id,
        t3.id as tag_db_system_id,
        n.is_deleted,
        n.deleted_at
    FROM app_hub.ndap_catalogue_app n
    LEFT JOIN app_hub.tags_reference t1 ON t1.name = n.tag_category AND t1.tag = 'category'
    LEFT JOIN app_hub.tags_reference t2 ON t2.name = n.tag_function_application AND t2.tag = 'function'
    LEFT JOIN app_hub.tags_reference t3 ON t3.name = n.tag_db_system AND t3.tag = 'db_system'
    WHERE 
        n.is_deleted = false AND
        (tag_ids IS NULL OR 
            (
                -- If there are any category tags (including 997), check if any match
                (NOT EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) AND t.tag = 'category'
                ) OR 
                (997 = ANY(tag_ids) AND n.tag_category IS NULL) OR
                EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) 
                    AND t.tag = 'category' 
                    AND t.name = n.tag_category
                ))
                AND
                -- If there are any function tags (including 998), check if any match
                (NOT EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) AND t.tag = 'function'
                ) OR 
                (998 = ANY(tag_ids) AND n.tag_function_application IS NULL) OR
                EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) 
                    AND t.tag = 'function' 
                    AND t.name = n.tag_function_application
                ))
                AND
                -- If there are any db_system tags (including 999), check if any match
                (NOT EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) AND t.tag = 'db_system'
                ) OR 
                (999 = ANY(tag_ids) AND n.tag_db_system IS NULL) OR
                EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) 
                    AND t.tag = 'db_system' 
                    AND t.name = n.tag_db_system
                ))
            )
        ) AND (
            -- Keyword searching
            search_keyword IS NULL OR
            n.vendor_name ILIKE '%' || search_keyword || '%' OR
            n.asset_name ILIKE '%' || search_keyword || '%'
        )
    ORDER BY n.vendor_name, n.asset_name;
END;
$function$
;



CREATE OR REPLACE FUNCTION app_hub.get_application_category()
 RETURNS TABLE(id Integer, tag text, name text, count bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        r.id as id,
        r.tag as tag,
        r.name as name,
        count(*) as count
    FROM app_hub.ndap_catalogue_app nc
    LEFT JOIN app_hub.tags_reference r ON (r.name = nc.tag_category or r.name = nc.tag_function_application or r.name = nc.tag_db_system)
    where r.tag is not null
    GROUP BY 1, 2, 3
    ORDER BY 4 DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION app_hub.get_application_catalog(search_keyword text DEFAULT NULL::text, tag_ids integer[] DEFAULT NULL::integer[])
 RETURNS TABLE(id integer, vendor_name character varying, asset_name character varying, description text, tag_category character varying, tag_function_application character varying, tag_db_system character varying, tag_category_id integer, tag_function_application_id integer, tag_db_system_id integer, is_deleted boolean, deleted_at timestamp without time zone, status varchar(255), decline_time timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.id,
        n.vendor_name,
        n.asset_name,
        n.description,
        n.tag_category,
        n.tag_function_application,
        n.tag_db_system,
        t1.id as tag_category_id,
        t2.id as tag_function_application_id,
        t3.id as tag_db_system_id,
        n.is_deleted,
        n.deleted_at,
        n.status,
        n.decline_time
    FROM app_hub.ndap_catalogue_app n
    LEFT JOIN app_hub.tags_reference t1 ON t1.name = n.tag_category AND t1.tag = 'category'
    LEFT JOIN app_hub.tags_reference t2 ON t2.name = n.tag_function_application AND t2.tag = 'function'
    LEFT JOIN app_hub.tags_reference t3 ON t3.name = n.tag_db_system AND t3.tag = 'db_system'
    WHERE 
        n.is_deleted = false and n.status = 'Live' and
        (tag_ids IS NULL OR 
            (
                -- If there are any category tags (including 997), check if any match
                (NOT EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) AND t.tag = 'category'
                ) OR 
                (997 = ANY(tag_ids) AND n.tag_category IS NULL) OR
                EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) 
                    AND t.tag = 'category' 
                    AND t.name = n.tag_category
                ))
                AND
                -- If there are any function tags (including 998), check if any match
                (NOT EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) AND t.tag = 'function'
                ) OR 
                (998 = ANY(tag_ids) AND n.tag_function_application IS NULL) OR
                EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) 
                    AND t.tag = 'function' 
                    AND t.name = n.tag_function_application
                ))
                AND
                -- If there are any db_system tags (including 999), check if any match
                (NOT EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) AND t.tag = 'db_system'
                ) OR 
                (999 = ANY(tag_ids) AND n.tag_db_system IS NULL) OR
                EXISTS (
                    SELECT 1 FROM app_hub.tags_reference t 
                    WHERE t.id = ANY(tag_ids) 
                    AND t.tag = 'db_system' 
                    AND t.name = n.tag_db_system
                ))
            )
        ) AND (
            -- Keyword searching
            search_keyword IS NULL OR
            n.vendor_name ILIKE '%' || search_keyword || '%' OR
            n.asset_name ILIKE '%' || search_keyword || '%'
        )
    ORDER BY n.vendor_name, n.asset_name;
END;
$function$
;

CREATE OR REPLACE FUNCTION app_hub.get_application_catalog_review(search_keyword text DEFAULT NULL::text)
 RETURNS TABLE(id integer, vendor_name character varying, asset_name character varying, description text, tag_category character varying, tag_function_application character varying, tag_db_system character varying, is_deleted boolean, deleted_at timestamp without time zone, status varchar(255), decline_time timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        n.id,
        n.vendor_name,
        n.asset_name,
        n.description,
        n.tag_category,
        n.tag_function_application,
        n.tag_db_system,
        n.is_deleted,
        n.deleted_at,
        case when n.status is null then 'On Review' else n.status end as status,
        n.decline_time
    FROM app_hub.ndap_catalogue_app n
    WHERE 
        n.is_deleted = false AND
        (
            (n.status = 'On Review' OR n.status is null) OR
            (n.status = 'Declined' AND n.decline_time >= NOW() - INTERVAL '24 hours')
        ) AND (
            -- Keyword searching
            search_keyword IS NULL OR
            n.vendor_name ILIKE '%' || search_keyword || '%' OR
            n.asset_name ILIKE '%' || search_keyword || '%'
        )
    ORDER BY n.vendor_name, n.asset_name;
END;
$function$; 



CREATE TABLE app_hub.application_request (
	id serial4 NOT NULL,
    requester_name varchar(255) NOT NULL,
    requester_department text NOT NULL,
    requester_nik varchar(255) NOT NULL,
	apps_owner_pic varchar(255) NOT NULL,
	apps_owner_department text NOT NULL,
    apps_custody_pic text NOT NULL,
    asset_name text NOT NULL,
    asset_objective text NOT NULL,
    description text NOT NULL,
    sustain_reason text NULL,
    is_public_facing boolean NOT NULL DEFAULT false,
    public_facing_data_sharing_target text NULL,
    is_contain_pii_data boolean NOT NULL DEFAULT false,
    pii_data_description text NULL,
    url text NULL,
    ip_address text NULL,
    asset_location_site_id text NULL,
    asset_location_site_name text NULL,
    tag_os_baseline varchar(255) NULL,
    tag_access_management varchar(255) NULL,
    status varchar(255) NOT NULL DEFAULT 'DEVELOPMENT',
    start_period date NULL,
    CONSTRAINT application_request_pkey PRIMARY KEY (id)
);

CREATE TABLE app_hub.data_management_store (
	id serial4 NOT NULL,
	name varchar(255) NOT NULL,
	CONSTRAINT data_management_store_pkey PRIMARY KEY (id)
);

CREATE TABLE app_hub.data_management_store_relation (
	id serial4 NOT NULL,
	application_request_id int4 NOT NULL,
	data_management_store_id int4 NOT NULL,
	CONSTRAINT data_management_store_relation_pkey PRIMARY KEY (id),
	CONSTRAINT data_management_store_relation_application_request_id_fkey FOREIGN KEY (application_request_id) REFERENCES app_hub.application_request(id),
	CONSTRAINT data_management_store_relation_data_management_store_id_fkey FOREIGN KEY (data_management_store_id) REFERENCES app_hub.data_management_store(id)
);

INSERT INTO app_hub.data_management_store (name) VALUES
('Payload'),
('Alarm Site or Cells'),
('Configuration Management Data (CM data)'),
('Power Site (Battery, Genset, etc)'),
('Coverage & Quality Data'),
('Incident and Complaint'),
('Business Process'),
('Ordering, Recurring and Payment'),
('Benchmark Data'),
('Revenue'),
('KPI / Performance (can be RHI, THI, Packetloss, 2G/4G/5G KPI, PM)'),
('Telkomsel Employee Data (can be Full Name, Email, NIK, Address, etc)'),
('Telkomsel Customer Data (can be MSISDN, Name, Address, Location, etc)'),
('NE Name (can be only NE name, IP, etc)'),
('Data Potensi Site (can be SiteID, SiteName, LongLat, Transport system, etc)'),
('Asset Data'),
('Transaction Data'),
('All Data OSS (Trace Files & CM Fliles GSM/LTE/5G NR, CHR Huawei, CTUM Ericsson, apcmd Nokia, SiteDB export from Ransys-Ironman)'),
('Vendor Data'),
('All Data Subscriber(IMSI, IMEI, Call Count, Block Call, Maker, Model)'),
('RSRP'),
('RSRQ'),
('Ticket Data'),
('Permit Data'),
('Ransys Data'),
('IOMS Acceptance Data'),
('EQP Data');


CREATE TABLE app_hub.application_portfolio (
	id serial4 NOT NULL,
    application_name varchar(255) NOT NULL,
    category varchar(255) NOT NULL,
    install_type varchar(255) NOT NULL,
	application_type varchar(255) NOT NULL,
	business_process text NULL,
    business_unit varchar(255) NULL,
    total_active_users int4 NOT NULL DEFAULT 0,
    version_age_status varchar(255) NULL,
    manufacturer varchar(255) NULL,
    CONSTRAINT application_portfolio_pkey PRIMARY KEY (id)
);

CREATE TABLE app_hub.application_usage (
	id serial4 NOT NULL,
    application_portfolio_id int4 NOT NULL,
    active_user_count int4 NOT NULL DEFAULT 0,
    CONSTRAINT application_usage_pkey PRIMARY KEY (id),
    CONSTRAINT application_usage_application_portfolio_id_fkey FOREIGN KEY (application_portfolio_id) REFERENCES app_hub.application_portfolio(id)
);

CREATE VIEW app_hub.install_type_summary AS
SELECT install_type, COUNT(*) AS total_apps
FROM app_hub.application_portfolio
GROUP BY install_type;

CREATE VIEW app_hub.category_manufacturer_summary AS
SELECT category, manufacturer, COUNT(*) AS jumlah_aplikasi
FROM app_hub.application_portfolio
GROUP BY category, manufacturer;

CREATE VIEW app_hub.category_version_status_summary AS
SELECT category, version_age_status, COUNT(*) AS jumlah_aplikasi
FROM app_hub.application_portfolio
GROUP BY category, version_age_status;

-- Initial 3 rows from the image
INSERT INTO app_hub.application_portfolio (application_name, category, install_type, application_type, business_process, business_unit, total_active_users, version_age_status, manufacturer) VALUES
('INAP', 'Customer Support', 'Cloud', 'Business App', 'Customer Handling', 'Unit A', 25000, 'Old Versions', 'Salesforce'),
('INEOM', 'Inventory Mgmt.', 'On Premise', 'Business App', 'Supply Chain', 'Unit B', 12000, 'Current', 'SAP'),
('Finance Control', 'Finance', 'Cloud', 'Business App', 'Financial Ops', 'Unit C', 10000, '1 Version Behind', 'Oracle');

-- Additional 17 dummy records with realistic variations
INSERT INTO app_hub.application_portfolio (application_name, category, install_type, application_type, business_process, business_unit, total_active_users, version_age_status, manufacturer) VALUES
('HR Portal', 'Human Resources', 'Cloud', 'Business App', 'Employee Management', 'Unit A', 18000, 'Current', 'Workday'),
('CRM Pro', 'Customer Support', 'Cloud', 'Business App', 'Sales Pipeline', 'Unit B', 15000, 'Current', 'Salesforce'),
('Inventory Plus', 'Inventory Mgmt.', 'On Premise', 'Business App', 'Warehouse Management', 'Unit C', 8000, '2 Versions Behind', 'SAP'),
('PayrollX', 'Finance', 'Cloud', 'Business App', 'Payroll Processing', 'Unit A', 5000, 'Current', 'ADP'),
('DocFlow', 'Document Management', 'Cloud', 'Business App', 'Content Management', 'Unit B', 22000, 'Current', 'Microsoft'),
('ServiceDesk', 'IT Support', 'Cloud', 'Business App', 'Ticket Management', 'Unit C', 3000, 'Current', 'ServiceNow'),
('ProjectHub', 'Project Management', 'Cloud', 'Business App', 'Project Tracking', 'Unit A', 7500, '1 Version Behind', 'Atlassian'),
('Analytics360', 'Business Intelligence', 'Cloud', 'Business App', 'Data Analytics', 'Unit B', 4500, 'Current', 'Tableau'),
('SecureAccess', 'Security', 'On Premise', 'Infrastructure', 'Access Control', 'Unit C', 30000, 'Current', 'Okta'),
('MailPro', 'Communication', 'Cloud', 'Business App', 'Email Services', 'Unit A', 28000, 'Current', 'Microsoft'),
('LearningMS', 'Training', 'Cloud', 'Business App', 'Employee Development', 'Unit B', 9000, 'Old Versions', 'Cornerstone'),
('ExpenseTrack', 'Finance', 'Cloud', 'Business App', 'Expense Management', 'Unit C', 17000, 'Current', 'Concur'),
('DataWarehouse', 'Data Management', 'On Premise', 'Infrastructure', 'Data Storage', 'Unit A', 2000, '1 Version Behind', 'Oracle'),
('TimeSheet', 'Human Resources', 'Cloud', 'Business App', 'Time Tracking', 'Unit B', 21000, 'Current', 'ADP'),
('QualityCheck', 'Quality Assurance', 'On Premise', 'Business App', 'Quality Control', 'Unit C', 4000, '2 Versions Behind', 'IBM'),
('AssetManager', 'Asset Management', 'Cloud', 'Business App', 'Asset Tracking', 'Unit A', 6000, 'Current', 'ServiceNow'),
('CompliancePro', 'Compliance', 'Cloud', 'Business App', 'Regulatory Compliance', 'Unit B', 3500, 'Current', 'MetricStream');

-- Insert dummy data for application_usage (last 3 months of usage data for each application)
INSERT INTO app_hub.application_usage (application_portfolio_id, active_user_count, date) VALUES
-- INAP (ID: 1) with growing usage
(1, 23000, '2024-01-31'),
(1, 24000, '2024-02-29'),
(1, 25000, '2024-03-31'),

-- INEOM (ID: 2) with stable usage
(2, 12000, '2024-01-31'),
(2, 12000, '2024-02-29'),
(2, 12000, '2024-03-31'),

-- Finance Control (ID: 3) with slight decline
(3, 10500, '2024-01-31'),
(3, 10200, '2024-02-29'),
(3, 10000, '2024-03-31'),

-- HR Portal (ID: 4) with growing usage
(4, 16000, '2024-01-31'),
(4, 17000, '2024-02-29'),
(4, 18000, '2024-03-31'),

-- CRM Pro (ID: 5) with fluctuating usage
(5, 14000, '2024-01-31'),
(5, 15500, '2024-02-29'),
(5, 15000, '2024-03-31'),

-- Inventory Plus (ID: 6) with stable usage
(6, 8000, '2024-01-31'),
(6, 8000, '2024-02-29'),
(6, 8000, '2024-03-31'),

-- PayrollX (ID: 7) with growing usage
(7, 4000, '2024-01-31'),
(7, 4500, '2024-02-29'),
(7, 5000, '2024-03-31'),

-- DocFlow (ID: 8) with high growth
(8, 18000, '2024-01-31'),
(8, 20000, '2024-02-29'),
(8, 22000, '2024-03-31'),

-- ServiceDesk (ID: 9) with stable usage
(9, 3000, '2024-01-31'),
(9, 3000, '2024-02-29'),
(9, 3000, '2024-03-31'),

-- ProjectHub (ID: 10) with moderate growth
(10, 6500, '2024-01-31'),
(10, 7000, '2024-02-29'),
(10, 7500, '2024-03-31'),

-- Analytics360 (ID: 11) with growing usage
(11, 3500, '2024-01-31'),
(11, 4000, '2024-02-29'),
(11, 4500, '2024-03-31'),

-- SecureAccess (ID: 12) with stable high usage
(12, 30000, '2024-01-31'),
(12, 30000, '2024-02-29'),
(12, 30000, '2024-03-31'),

-- MailPro (ID: 13) with slight growth
(13, 27000, '2024-01-31'),
(13, 27500, '2024-02-29'),
(13, 28000, '2024-03-31'),

-- LearningMS (ID: 14) with declining usage
(14, 10000, '2024-01-31'),
(14, 9500, '2024-02-29'),
(14, 9000, '2024-03-31'),

-- ExpenseTrack (ID: 15) with growing usage
(15, 15000, '2024-01-31'),
(15, 16000, '2024-02-29'),
(15, 17000, '2024-03-31'),

-- DataWarehouse (ID: 16) with stable usage
(16, 2000, '2024-01-31'),
(16, 2000, '2024-02-29'),
(16, 2000, '2024-03-31'),

-- TimeSheet (ID: 17) with growing usage
(17, 19000, '2024-01-31'),
(17, 20000, '2024-02-29'),
(17, 21000, '2024-03-31'),

-- QualityCheck (ID: 18) with slight decline
(18, 4500, '2024-01-31'),
(18, 4200, '2024-02-29'),
(18, 4000, '2024-03-31'),

-- AssetManager (ID: 19) with growing usage
(19, 5000, '2024-01-31'),
(19, 5500, '2024-02-29'),
(19, 6000, '2024-03-31'),

-- CompliancePro (ID: 20) with stable usage
(20, 3500, '2024-01-31'),
(20, 3500, '2024-02-29'),
(20, 3500, '2024-03-31');

INSERT INTO app_hub.ndap_catalogue_app (
    id,
    status_division,
    division,
    asset_type,
    asset_name,
    description,
    principle,
    vendor_name,
    source_data_application,
    tag_db_system,
    tag_function_application,
    tag_domain,
    tag_category,
    data_retentation,
    data_processing_management,
    output_application,
    format_export_data,
    public_facing,
    contain_pii_data,
    data_pii_detail,
    tag_log_user,
    url,
    ip_address,
    asset_location_site_id,
    asset_location_site_name,
    inhouse_vendor,
    tag_os_baseline,
    tag_access_management,
    asset_owner_department,
    apps_owner_pic,
    status
) VALUES 
(9998, 'NDAP', 'Network Digitalization and Analytics Platform Division', 'WEB Aplikasi', 'Dummy App 1', 'Customer self-service portal for account management', 'John Doe', 'In-house', 'Customer database, Billing system', 'Database - PostgreSQL', 'Communication, Interaction, Coordination', 'RAN', 'Data Warehouse', 'Daily', 'Daily batch processing', 'Customer reports, Analytics dashboard', 'CSV, JSON', 'Yes', 'Yes', 'Customer name, address, phone', 'Active Directory', 'https://portal.example.com', '192.168.1.100', 'SITE001', 'Headquarters', 'Inhouse', 'Windows Server 2019', 'LDAP', 'Customer Service Department', 'Jane Smith', 'Live'),
(9999, 'NDAP', 'Network Digitalization and Analytics Platform Division', 'Mobile Apps', 'Dummy App 2', 'System for financial reporting and analysis', 'Mike Johnson', 'Oracle', 'ERP system, Accounting software', 'Database - PostgreSQL', 'Communication, Interaction, Coordination', 'RAN', 'Data Warehouse', 'Daily', 'Real-time processing', 'Financial reports, Statements', 'PDF, Excel', 'No', 'Yes', 'Financial records, Employee salary', 'Database authentication', 'N/A', '192.168.1.101', 'SITE002', 'Data Center', 'Vendor', 'Linux', 'LDAP', 'Finance Department', 'Sarah Wilson', 'Live');

-- Function to perform soft delete on a record
CREATE OR REPLACE FUNCTION app_hub.soft_delete_ndap_catalogue_app(
    p_table_name VARCHAR,
    p_id BIGINT
)
RETURNS VOID AS $$
BEGIN
    EXECUTE format('
        UPDATE %I 
        SET is_deleted = true, 
            deleted_at = CURRENT_TIMESTAMP
        WHERE id = $1
    ', p_table_name)
    USING p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app_hub.get_category_manufacturer_matrix()
RETURNS TABLE (
    category varchar(255),
    manufacturer varchar(255),
    count bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH all_categories AS (
        SELECT DISTINCT ap.category FROM app_hub.application_portfolio ap
    ),
    all_manufacturers AS (
        SELECT DISTINCT ap.manufacturer FROM app_hub.application_portfolio ap WHERE ap.manufacturer IS NOT NULL
    ),
    cross_join AS (
        SELECT ac.category, am.manufacturer
        FROM all_categories ac
        CROSS JOIN all_manufacturers am
    )
    SELECT 
        cj.category,
        cj.manufacturer,
        COALESCE(aps.count, 0)::bigint as count
    FROM cross_join cj
    LEFT JOIN (
        SELECT ap.category, ap.manufacturer, COUNT(*) as count
        FROM app_hub.application_portfolio ap
        GROUP BY ap.category, ap.manufacturer
    ) aps ON cj.category = aps.category AND cj.manufacturer = aps.manufacturer
    ORDER BY cj.category, cj.manufacturer;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app_hub.get_category_version_status_matrix()
RETURNS TABLE (
    category varchar(255),
    version_age_status varchar(255),
    count bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH all_categories AS (
        SELECT DISTINCT ap.category FROM app_hub.application_portfolio ap
    ),
    all_version_statuses AS (
        SELECT DISTINCT ap.version_age_status FROM app_hub.application_portfolio ap WHERE ap.version_age_status IS NOT NULL
    ),
    cross_join AS (
        SELECT ac.category, avs.version_age_status
        FROM all_categories ac
        CROSS JOIN all_version_statuses avs
    )
    SELECT 
        cj.category,
        cj.version_age_status,
        COALESCE(aps.count, 0)::bigint as count
    FROM cross_join cj
    LEFT JOIN (
        SELECT ap.category, ap.version_age_status, COUNT(*) as count
        FROM app_hub.application_portfolio ap
        GROUP BY ap.category, ap.version_age_status
    ) aps ON cj.category = aps.category AND cj.version_age_status = aps.version_age_status
    ORDER BY cj.category, cj.version_age_status;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app_hub.get_top_10_by_total_active_users(column_name text)
RETURNS TABLE (
    value text,
    total_active_users bigint
) AS $$
BEGIN
    RETURN QUERY EXECUTE format('
        SELECT 
            CAST(ap.%I AS text) as value,
            SUM(ap.total_active_users) as total_active_users
        FROM app_hub.application_portfolio ap
        GROUP BY value
        ORDER BY total_active_users DESC
        LIMIT 10', 
        column_name);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app_hub.get_apps_count_by_column(column_name text)
RETURNS TABLE (
    value text,
    count bigint
) AS $$
BEGIN
    RETURN QUERY EXECUTE format('
        SELECT 
            CAST(%I AS text) as value,
            COUNT(*) as count
        FROM app_hub.application_portfolio
        GROUP BY %I
        ORDER BY count DESC', 
        column_name, column_name);
END;
$$ LANGUAGE plpgsql;

CREATE TABLE app_hub.filter_reference (
	id serial4 NOT NULL,
    name varchar(255) NOT NULL,
    display_name varchar(255) NOT NULL,
	context varchar(255) NOT NULL,
    CONSTRAINT filter_reference_pkey PRIMARY KEY (id)
);

CREATE OR REPLACE FUNCTION app_hub.get_filters_by_context(filter_context varchar(255))
RETURNS TABLE (
    name varchar(255),
    display_name varchar(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        fr.name,
        fr.display_name
    FROM app_hub.filter_reference fr
    WHERE fr.context = filter_context
    ORDER BY fr.display_name;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app_hub.get_group_by_filter_for_top_10_by_total_active_users()
RETURNS TABLE (
    name varchar(255),
    display_name varchar(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT * from app_hub.get_filters_by_context('FILTER_TOP_10_BY_TOTAL_USER');
END;
$$ LANGUAGE plpgsql;

INSERT INTO app_hub.filter_reference("name", display_name, context) VALUES('application_name', 'Application Name', 'FILTER_TOP_10_BY_TOTAL_USER');
INSERT INTO app_hub.filter_reference("name", display_name, context) VALUES('category', 'Category', 'FILTER_TOP_10_BY_TOTAL_USER');
INSERT INTO app_hub.filter_reference("name", display_name, context) VALUES('manufacturer', 'Manufacturer', 'FILTER_TOP_10_BY_TOTAL_USER');
INSERT INTO app_hub.filter_reference("name", display_name, context) VALUES('install_type', 'Install Type', 'FILTER_TOP_10_BY_TOTAL_USER');

CREATE TABLE app_hub.catalogue_hub_temp (
	id serial4 NOT NULL,
	tenant_aplikasi varchar(255) NULL,
	device_ip_address varchar(255) NULL,
	hostname_device_name varchar(255) NULL,
	device_type varchar(255) NULL,
	device_type_name varchar(255) NULL,
	os varchar(50) NULL,
	"function" varchar(255) NULL,
	cpu int4 NULL,
	memory_gb int8 NULL,
	disk_gb int8 null,
	server_location varchar(255) null,
	CONSTRAINT catalogue_hub_temp_pkey PRIMARY KEY (id)
);

CREATE OR REPLACE FUNCTION app_hub.get_app_details_by_id(p_id integer)
RETURNS TABLE (
	id int4,
    asset_name varchar(255),
    vendor_name varchar(255),
    apps_owner_pic varchar(255),
    owner_phone_number varchar,
    tsa varchar,
    status varchar(255),
    version varchar,
    description text,
    principle varchar(255),
    is_deleted bool,
    deleted_at timestamp,
    decline_time timestamp,
    tags text[]
) 
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
    	n.id,
        n.asset_name,
        n.vendor_name,
        n.apps_owner_pic,
        n.owner_phone_number,
        n.tsa,
        case when n.status is null then 'On Review' else n.status end as status,
        n.version,
        n.description,
        n.principle,
        n.is_deleted,
        n.deleted_at,
        n.decline_time,
        ARRAY_REMOVE(ARRAY[
            n.tag_db_system::text,
            n.tag_function_application::text,
            n.tag_category::text
        ], NULL) as tags
    FROM app_hub.ndap_catalogue_app n
    WHERE n.id = p_id;
END;
$function$;

CREATE SEQUENCE app_hub."ndap_catalogue_app_id_seq";
SELECT setval('app_hub.ndap_catalogue_app_id_seq', (SELECT MAX("id") FROM app_hub."ndap_catalogue_app"));    
ALTER TABLE app_hub."ndap_catalogue_app"
   ALTER COLUMN "id" SET DEFAULT nextval('app_hub.ndap_catalogue_app_id_seq'),
   ALTER COLUMN "id" SET NOT NULL;


SELECT pg_get_serial_sequence('app_hub.ndap_catalogue_app', 'id');

ALTER TABLE app_hub.ndap_catalogue_app
ADD COLUMN IF NOT EXISTS is_public_facing bool NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS is_contain_pii_data bool NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS pii_data_description text null,
ADD COLUMN requester_name varchar(255),
ADD COLUMN requester_department text,
ADD COLUMN requester_nik varchar(255),
ADD COLUMN apps_custody_pic text,
ADD COLUMN asset_objective text,
ADD COLUMN sustain_reason text,
ADD COLUMN public_facing_data_sharing_target text,
ADD COLUMN start_period date,
ADD COLUMN apps_development_pic varchar(255);

ALTER TABLE app_hub.ndap_catalogue_app
ADD COLUMN IF NOT EXISTS decline_time timestamp NULL;


CREATE TABLE app_hub.security_assessment (
	id serial4 NOT NULL,
	security_name varchar(255) NULL,
	apps varchar(255) NULL,
	severity_critical int4 NULL,
	severity_high int4 NULL,
	severity_medium int4 NULL,
	severity_low int4 NULL,
	total int4 NULL,
	status varchar(255) NULL,
	remark varchar(255) NULL,
	CONSTRAINT security_assessment_pkey PRIMARY KEY (id)
);

