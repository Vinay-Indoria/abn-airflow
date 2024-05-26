{% set file_name = ti.xcom_pull(task_ids=params.task_id) %}
BEGIN;

/* 
get and insert unique abns 
if there are multiple ABN's then we wil take the latest crawled one and its domain
*/ 
with data_cte as (
	select abn,
        domain_name,
        warc_date,
        index_file_name, 
        row_number() over (partition by abn order by warc_date desc) as RN 
    from mds.mining_abn_data_raw mad 
    where abn is not null and index_file_name = '{{file_name}}'
)
insert into mds.abn_mining_data (abn, domain_name, warc_date, index_file_name) 
select CAST(abn AS BIGINT), domain_name, warc_date, index_file_name from data_cte where RN = 1;

/* 
now we will be unnestting the industries from the puleld ABN data 
Firstly we will get the aggegated unique industries of a particular ABN in array format
Then we will unnest it to get specific individual rows of abn and industry name
Then we will join it to australian master industries table to get the association table in place
*/
Insert into mds.abn_mining_industry_mapping (abn, industry_id)
WITH normalized_industry_data AS (
    SELECT
        abn,
        ARRAY_AGG(DISTINCT UPPER(industry) ORDER BY UPPER(industry)) AS industries
    FROM (
        SELECT
            abn,
            unnest(string_to_array(industries, ',')) AS industry
        FROM
            mds.mining_abn_data_raw
        WHERE
            index_file_name = '{{file_name}}'
    ) subquery
    WHERE
        industry IS NOT NULL
    GROUP BY
        abn
),
unnested_indsutry_data AS (
    SELECT
        nm.abn,
        unnest(nm.industries) AS industry_name
    FROM
        normalized_industry_data nm
)
SELECT
    CAST(ud.abn as BIGINT),
    mi.industry_id
FROM
    unnested_indsutry_data ud
JOIN
    mds.australian_industries mi ON mi.industry_name = ud.industry_name;

COMMIT;