/* We have pass task_id parameter to access only the given records*/
{% set file_name = ti.xcom_pull(task_ids=params.task_id, key='file_name') %}
BEGIN;

/* Inserting records from raw abn table to main table*/
insert into mds.abn_data (abn, status, abn_status_from_date, business_type_code, gst, gst_status , gst_status_from_date, replaced, record_last_updated_date )
select abn, abn_status, abn_status_from_date , business_type_code, gst, gst_status , gst_from_date , is_replaced, last_record_updated_date
from raw.abn_bulk_data where file_name = '{{ file_name }}';

/* Inserting entity data from the same raw table */
insert into mds.entity_master (abn, business_name, name_title, given_name, family_name, business_address_state, business_address_post_code, is_individual, type_code)
select abn, business_name, name_title, given_name, family_name, business_state, business_postcode, is_individual, entity_type_code 
from raw.abn_bulk_data where file_name = '{{ file_name }}';

/* perform the update for entity_master_id for newly added records*/
/* we will work only with records which are recently added and there are no entity ascociation present*/
update mds.abn_data 
set entity_master_id = em.id 
from mds.entity_master em
where abn_data.abn = em.abn and entity_master_id is null;

/* Inserting DGR data from the raw dgr table */
insert into mds.abn_dgr (abn, type_code, business_name, dgr_status_from_date)
select abn, type_code, business_name, dgr_status_from_date 
from raw.abn_dgr_bulk_data where file_name = '{{ file_name }}';

/* Inserting Other entiry data from the raw other entity table */
insert into mds.abn_other_entity (abn, type_code, business_name)
select abn, type_code, business_name
from raw.abn_other_entity_bulk_data where file_name = '{{ file_name }}';

COMMIT;