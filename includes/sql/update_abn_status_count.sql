{% set json_task_output = task_instance.xcom_pull(task_ids=params.task_id) %}
{% set file_name = ti.xcom_pull(task_ids=params.file_name_task_id) %}
{% set dag_run_id = dag_run.run_id %}

BEGIN;

/*
We will just update the counts pulled from previous task to get the records which were success
We already have total count in the same table
*/
Update mds.mining_dag_run_stats set
downloaded_au_files_count = '{{ json_task_output.get("total_downloaded_files_count", 0) }}',
successful_file_parse_count = '{{ json_task_output.get("successful_parse_count", 0) }}'
where dag_run_id = '{{dag_run_id}}';

/*
Here we need to pull some records from the two working tables namely from mining_abn_data_raw table and abn_mining_data
we could have pulled both unique_domain_count and unique_abn_count from mining_abn_data_raw but just for clarity
we are considering only the final table count
*/
Update mds.mining_dag_run_stats set
unique_domain_count = (select count(distinct domain_name) from mds.mining_abn_data_raw where index_file_name = '{{file_name}}'),
unique_abn_count = (select count(distinct abn) from mds.abn_mining_data where index_file_name = '{{file_name}}'),
end_timestamp = current_timestamp AT TIME ZONE 'UTC'
where dag_run_id = '{{dag_run_id}}';

COMMIT;