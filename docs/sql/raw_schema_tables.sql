-- raw.abn_bulk_data definition

-- Drop table

-- DROP TABLE raw.abn_bulk_data;

CREATE TABLE raw.abn_bulk_data (
	abn int8 NOT NULL,
	abn_status varchar(3) NULL,
	abn_status_from_date date NULL,
	business_type_code varchar(4) NULL,
	business_name varchar(200) NULL,
	name_title varchar(50) NULL,
	given_name varchar(100) NULL,
	family_name varchar(50) NULL,
	entity_type_code varchar(3) NULL,
	business_state varchar(3) NULL,
	business_postcode varchar(50) NULL,
	is_individual bool NOT NULL,
	gst varchar(20) NULL,
	gst_status varchar(3) NULL,
	gst_from_date date NULL,
	file_name varchar(200) NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	is_replaced bool NULL DEFAULT false,
	last_record_updated_date date NULL,
	CONSTRAINT abn_bulk_data_pkey PRIMARY KEY (abn)
);
CREATE INDEX abn_bulk_data_file_name_idx ON raw.abn_bulk_data USING btree (file_name);


-- raw.abn_dgr_bulk_data definition

-- Drop table

-- DROP TABLE raw.abn_dgr_bulk_data;

CREATE TABLE raw.abn_dgr_bulk_data (
	id serial4 NOT NULL,
	abn int8 NOT NULL,
	type_code varchar(3) NULL,
	business_name varchar(200) NOT NULL,
	dgr_status_from_date date NULL,
	file_name varchar(200) NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT abn_dgr_bulk_data_pkey PRIMARY KEY (id)
);
CREATE INDEX abn_dgr_bulk_data_file_name_idx ON raw.abn_dgr_bulk_data USING btree (file_name);


-- raw.abn_other_entity_bulk_data definition

-- Drop table

-- DROP TABLE raw.abn_other_entity_bulk_data;

CREATE TABLE raw.abn_other_entity_bulk_data (
	id serial4 NOT NULL,
	abn int8 NOT NULL,
	type_code varchar(3) NULL,
	business_name varchar(200) NOT NULL,
	file_name varchar(200) NULL,
	created_at timestamptz NULL DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT abn_other_entity_bulk_data_pkey PRIMARY KEY (id)
);
CREATE INDEX abn_other_entity_bulk_data_file_name_idx ON raw.abn_other_entity_bulk_data USING btree (file_name);