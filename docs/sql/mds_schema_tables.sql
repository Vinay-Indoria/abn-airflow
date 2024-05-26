-- mds.abn_mining_data definition

-- Drop table

-- DROP TABLE mds.abn_mining_data;

CREATE TABLE mds.abn_mining_data (
	abn int8 NOT NULL,
	domain_name varchar(500) NULL,
	warc_date timestamptz NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	index_file_name varchar(50) NULL,
	CONSTRAINT abn_mining_data_pkey PRIMARY KEY (abn)
);


-- mds.australian_industries definition

-- Drop table

-- DROP TABLE mds.australian_industries;

CREATE TABLE mds.australian_industries (
	industry_id serial4 NOT NULL,
	industry_name varchar(100) NOT NULL,
	CONSTRAINT australian_industries_pkey PRIMARY KEY (industry_id)
);


-- mds.business_type_master definition

-- Drop table

-- DROP TABLE mds.business_type_master;

CREATE TABLE mds.business_type_master (
	code varchar(4) NOT NULL,
	display_text varchar(100) NULL,
	CONSTRAINT entity_type_master_pk PRIMARY KEY (code)
);
CREATE UNIQUE INDEX entity_type_master_code_idx ON mds.business_type_master USING btree (code);


-- mds.ccrwl_index_2024_18 definition

-- Drop table

-- DROP TABLE mds.ccrwl_index_2024_18;

CREATE TABLE mds.ccrwl_index_2024_18 (
	id int2 NOT NULL,
	index_upload_date date NULL,
	index_upload_time time NULL,
	size_bytes varchar NULL,
	file_name varchar NULL,
	is_processed bool NULL DEFAULT false,
	CONSTRAINT ccrwl_index_2024_18_pk PRIMARY KEY (id)
);


-- mds.mining_abn_data_raw definition

-- Drop table

-- DROP TABLE mds.mining_abn_data_raw;

CREATE TABLE mds.mining_abn_data_raw (
	id int4 NOT NULL DEFAULT nextval('mds.mining_abn_data_id_seq'::regclass),
	abn varchar(15) NULL,
	warc_url varchar(300) NULL,
	warc_date timestamptz NULL,
	domain_name varchar(250) NULL,
	warc_file_name varchar(200) NULL,
	index_file_name varchar(50) NULL,
	page_content text NULL,
	business_entity_name text NULL,
	industries text NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT mining_abn_data_pkey PRIMARY KEY (id)
);
CREATE INDEX mining_abn_data_abn_idx ON mds.mining_abn_data_raw USING btree (abn);
CREATE INDEX mining_abn_data_domain_name_idx ON mds.mining_abn_data_raw USING btree (domain_name);
CREATE INDEX mining_abn_data_index_file_name_idx ON mds.mining_abn_data_raw USING btree (index_file_name);


-- mds.mining_dag_run_stats definition

-- Drop table

-- DROP TABLE mds.mining_dag_run_stats;

CREATE TABLE mds.mining_dag_run_stats (
	dag_run_id varchar NOT NULL,
	file_name varchar NOT NULL,
	total_records int4 NULL,
	filtered_au_records int4 NULL,
	unique_domain_count int4 NULL,
	unique_abn_count int4 NULL,
	execution_timestamp timestamp NULL,
	downloaded_au_files_count int4 NULL,
	successful_file_parse_count int4 NULL,
	end_timestamp timestamptz NULL
);


-- mds.abn_mining_industry_mapping definition

-- Drop table

-- DROP TABLE mds.abn_mining_industry_mapping;

CREATE TABLE mds.abn_mining_industry_mapping (
	id serial4 NOT NULL,
	abn int8 NULL,
	industry_id int4 NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT abn_mining_industry_mapping_pkey PRIMARY KEY (id),
	CONSTRAINT abn_mining_industry_mapping_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES mds.australian_industries(industry_id)
);


-- mds.abn_data definition

-- Drop table

-- DROP TABLE mds.abn_data;

CREATE TABLE mds.abn_data (
	abn int8 NOT NULL,
	status varchar(3) NOT NULL,
	abn_status_from_date date NULL,
	record_last_updated_date date NULL,
	business_type_code varchar(4) NULL,
	gst varchar(20) NULL,
	gst_status varchar(3) NULL,
	gst_status_from_date date NULL,
	entity_master_id uuid NULL,
	replaced bool NULL DEFAULT false,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT abn_data_pkey PRIMARY KEY (abn)
);


-- mds.abn_dgr definition

-- Drop table

-- DROP TABLE mds.abn_dgr;

CREATE TABLE mds.abn_dgr (
	id serial4 NOT NULL,
	abn int8 NOT NULL,
	type_code varchar(3) NULL,
	business_name varchar(200) NOT NULL,
	dgr_status_from_date date NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT abn_dgr_pkey PRIMARY KEY (id)
);


-- mds.abn_other_entity definition

-- Drop table

-- DROP TABLE mds.abn_other_entity;

CREATE TABLE mds.abn_other_entity (
	id serial4 NOT NULL,
	abn int8 NOT NULL,
	type_code varchar(3) NULL,
	business_name varchar(200) NOT NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT abn_other_entity_pkey PRIMARY KEY (id)
);


-- mds.entity_master definition

-- Drop table

-- DROP TABLE mds.entity_master;

CREATE TABLE mds.entity_master (
	id uuid NOT NULL DEFAULT mds.uuid_generate_v4(),
	abn int8 NOT NULL,
	business_name varchar(200) NULL,
	name_title varchar(50) NULL,
	given_name varchar(100) NULL,
	family_name varchar(50) NULL,
	business_address_state varchar(3) NULL,
	business_address_post_code varchar(50) NULL,
	is_individual bool NOT NULL,
	type_code varchar(3) NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT entity_master_pkey PRIMARY KEY (id)
);
CREATE INDEX entity_master_abn_idx ON mds.entity_master USING btree (abn);
CREATE INDEX entity_master_business_address_state_idx ON mds.entity_master USING btree (business_address_state, business_address_post_code);
CREATE UNIQUE INDEX entity_master_id_idx ON mds.entity_master USING btree (id);
CREATE INDEX entity_master_is_individual_idx ON mds.entity_master USING btree (is_individual);


-- mds.abn_data foreign keys

ALTER TABLE mds.abn_data ADD CONSTRAINT abn_data_entity_master_id_fkey FOREIGN KEY (entity_master_id) REFERENCES mds.entity_master(id);
ALTER TABLE mds.abn_data ADD CONSTRAINT abn_data_entity_type_code_fkey FOREIGN KEY (business_type_code) REFERENCES mds.business_type_master(code);


-- mds.abn_dgr foreign keys

ALTER TABLE mds.abn_dgr ADD CONSTRAINT abn_dgr_abn_fkey FOREIGN KEY (abn) REFERENCES mds.abn_data(abn);


-- mds.abn_other_entity foreign keys

ALTER TABLE mds.abn_other_entity ADD CONSTRAINT abn_other_entity_abn_fkey FOREIGN KEY (abn) REFERENCES mds.abn_data(abn);


-- mds.entity_master foreign keys

ALTER TABLE mds.entity_master ADD CONSTRAINT entity_master_fk FOREIGN KEY (abn) REFERENCES mds.abn_data(abn);