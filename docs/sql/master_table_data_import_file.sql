/*
You can add autorization to the schema as well
CREATE SCHEMA mds AUTHORIZATION postgres;
CREATE SCHEMA mds AUTHORIZATION {username};
*/
CREATE SCHEMA mds;
CREATE SCHEMA raw;

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


INSERT INTO mds.australian_industries (industry_name) VALUES
	 ('AGRICULTURE'),
	 ('MINING'),
	 ('MANUFACTURING'),
	 ('CONSTRUCTION'),
	 ('WHOLESALE TRADE'),
	 ('RETAIL TRADE'),
	 ('ACCOMMODATION AND FOOD SERVICES'),
	 ('TRANSPORT AND LOGISTICS'),
	 ('INFORMATION MEDIA AND TELECOMMUNICATIONS'),
	 ('FINANCIAL AND INSURANCE SERVICES');
INSERT INTO mds.australian_industries (industry_name) VALUES
	 ('RENTAL, HIRING, AND REAL ESTATE SERVICES'),
	 ('PROFESSIONAL, SCIENTIFIC, AND TECHNICAL SERVICES'),
	 ('ADMINISTRATIVE AND SUPPORT SERVICES'),
	 ('PUBLIC ADMINISTRATION AND SAFETY'),
	 ('EDUCATION AND TRAINING'),
	 ('HEALTH CARE AND SOCIAL ASSISTANCE'),
	 ('ARTS AND RECREATION SERVICES'),
	 ('UTILITIES');



INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('ADF','Approved Deposit Fund'),
	 ('ARF','APRA Regulated Fund (Fund Type Unknown)'),
	 ('CCB','Commonwealth Government Public Company'),
	 ('CCC','Commonwealth Government Co-operative'),
	 ('CCL','Commonwealth Government Limited Partnership'),
	 ('CCN','Commonwealth Government Other Unincorporated Entity'),
	 ('CCO','Commonwealth Government Other Incorporated Entity'),
	 ('CCP','Commonwealth Government Pooled Development Fund'),
	 ('CCR','Commonwealth Government Private Company'),
	 ('CCS','Commonwealth Government Strata Title');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('CCT','Commonwealth Government Public Trading Trust'),
	 ('CCU','Commonwealth Government Corporate Unit Trust'),
	 ('CGA','Commonwealth Government Statutory Authority'),
	 ('CGC','Commonwealth Government Company'),
	 ('CGE','Commonwealth Government Entity'),
	 ('CGP','Commonwealth Government Partnership'),
	 ('CGS','Commonwealth Government Super Fund'),
	 ('CGT','Commonwealth Government Trust'),
	 ('CMT','Cash Management Trust'),
	 ('COP','Co-operative');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('CSA','Commonwealth Government APRA Regulated Public Sector Fund'),
	 ('CSP','Commonwealth Government APRA Regulated Public Sector Scheme'),
	 ('CSS','Commonwealth Government Non-Regulated Super Fund'),
	 ('CTC','Commonwealth Government Cash Management Trust'),
	 ('CTD','Commonwealth Government Discretionary Services Management Trust'),
	 ('CTF','Commonwealth Government Fixed Trust'),
	 ('CTH','Commonwealth Government Hybrid Trust'),
	 ('CTI','Commonwealth Government Discretionary Investment Trust'),
	 ('CTL','Commonwealth Government Listed Public Unit Trust'),
	 ('CTQ','Commonwealth Government Unlisted Public Unit Trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('CTT','Commonwealth Government Discretionary Trading Trust'),
	 ('CTU','Commonwealth Government Fixed Unit Trust'),
	 ('CUT','Corporate Unit Trust'),
	 ('DES','Deceased Estate'),
	 ('DIP','Diplomatic/Consulate Body or High Commissioner'),
	 ('DIT','Discretionary Investment Trust'),
	 ('DST','Discretionary Services Management Trust'),
	 ('DTT','Discretionary Trading Trust'),
	 ('FHS','First Home Saver Accounts Trust'),
	 ('FPT','Family Partnership');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('FUT','Fixed Unit Trust'),
	 ('FXT','Fixed Trust'),
	 ('HYT','Hybrid Trust'),
	 ('IND','Individual/Sole Trader'),
	 ('LCB','Local Government Public Company'),
	 ('LCC','Local Government Co-operative'),
	 ('LCL','Local Government Limited Partnership'),
	 ('LCN','Local Government Other Unincorporated Entity'),
	 ('LCO','Local Government Other Incorporated Entity'),
	 ('LCP','Local Government Pooled Development Fund');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('LCR','Local Government Private Company'),
	 ('LCS','Local Government Strata Title'),
	 ('LCT','Local Government Public Trading Trust'),
	 ('LCU','Local Government Corporate Unit Trust'),
	 ('LGA','Local Government Statutory Authority'),
	 ('LGC','Local Government Company'),
	 ('LGE','Local Government Entity'),
	 ('LGP','Local Government Partnership'),
	 ('LGT','Local Government Trust'),
	 ('LPT','Limited Partnership');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('LSA','Local Government APRA Regulated Public Sector Fund'),
	 ('LSP','Local Government APRA Regulated Public Sector Scheme'),
	 ('LSS','Local Government Non-Regulated Super Fund'),
	 ('LTC','Local Government Cash Management Trust'),
	 ('LTD','Local Government Discretionary Services Management Trust'),
	 ('LTF','Local Government Fixed Trust'),
	 ('LTH','Local Government Hybrid Trust'),
	 ('LTI','Local Government Discretionary Investment Trust'),
	 ('LTL','Local Government Listed Public Unit Trust'),
	 ('LTQ','Local Government Unlisted Public Unit Trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('LTT','Local Government Discretionary Trading Trust'),
	 ('LTU','Local Government Fixed Unit Trust'),
	 ('NPF','APRA Regulated Non-Public Offer Fund'),
	 ('NRF','Non-Regulated Superannuation Fund'),
	 ('OIE','Other Incorporated Entity'),
	 ('PDF','Pooled Development Fund'),
	 ('POF','APRA Regulated Public Offer Fund'),
	 ('PQT','Unlisted Public Unit Trust'),
	 ('PRV','Australian Private Company'),
	 ('PST','Pooled Superannuation Trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('PTR','Other Partnership'),
	 ('PTT','Public Trading trust'),
	 ('PUB','Australian Public Company'),
	 ('PUT','Listed Public Unit Trust'),
	 ('SAF','Small APRA Regulated Fund'),
	 ('SCB','State Government Public Company'),
	 ('SCC','State Government Co-operative'),
	 ('SCL','State Government Limited Partnership'),
	 ('SCN','State Government Other Unincorporated Entity'),
	 ('SCO','State Government Other Incorporated Entity');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('SCP','State Government Pooled Development Fund'),
	 ('SCR','State Government Private Company'),
	 ('SCS','State Government Strata Title'),
	 ('SCT','State Government Public Trading Trust'),
	 ('SCU','State Government Corporate Unit Trust'),
	 ('SGA','State Government Statutory Authority'),
	 ('SGC','State Government Company'),
	 ('SGE','State Government Entity'),
	 ('SGP','State Government Partnership'),
	 ('SGT','State Government Trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('SMF','ATO Regulated Self-Managed Superannuation Fund'),
	 ('SSA','State Government APRA Regulated Public Sector Fund'),
	 ('SSP','State Government APRA Regulated Public Sector Scheme'),
	 ('SSS','State Government Non-Regulated Super Fund'),
	 ('STC','State Government Cash Management Trust'),
	 ('STD','State Government Discretionary Services Management Trust'),
	 ('STF','State Government Fixed Trust'),
	 ('STH','State Government Hybrid Trust'),
	 ('STI','State Government Discretionary Investment Trust'),
	 ('STL','State Government Listed Public Unit Trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('STQ','State Government Unlisted Public Unit Trust'),
	 ('STR','Strata-title'),
	 ('STT','State Government Discretionary Trading Trust'),
	 ('STU','State Government Fixed Unit Trust'),
	 ('SUP','Super Fund'),
	 ('TCB','Territory Government Public Company'),
	 ('TCC','Territory Government Co-operative'),
	 ('TCL','Territory Government Limited Partnership'),
	 ('TCN','Territory Government Other Unincorporated Entity'),
	 ('TCO','Territory Government Other Incorporated Entity');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('TCP','Territory Government Pooled Development Fund'),
	 ('TCR','Territory Government Private Company'),
	 ('TCS','Territory Government Strata Title'),
	 ('TCT','Territory Government Public Trading Trust'),
	 ('TCU','Territory Government Corporate Unit Trust'),
	 ('TGA','Territory Government Statutory Authority'),
	 ('TGE','Territory Government Entity'),
	 ('TGP','Territory Government Partnership'),
	 ('TGT','Territory Government Trust'),
	 ('TRT','Other trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('TSA','Territory Government APRA Regulated Public Sector Fund'),
	 ('TSP','Territory Government APRA Regulated Public Sector Scheme'),
	 ('TSS','Territory Government Non-Regulated Super Fund'),
	 ('TTC','Territory Government Cash Management Trust'),
	 ('TTD','Territory Government Discretionary Services Management Trust'),
	 ('TTF','Territory Government Fixed Trust'),
	 ('TTH','Territory Government Hybrid Trust'),
	 ('TTI','Territory Government Discretionary Investment Trust'),
	 ('TTL','Territory Government Listed Public Unit Trust'),
	 ('TTQ','Territory Government Unlisted Public Unit Trust');
INSERT INTO mds.business_type_master (code,display_text) VALUES
	 ('TTT','Territory Government Discretionary Trading Trust'),
	 ('TTU','Territory Government Fixed Unit Trust'),
	 ('UIE','Other Unincorporated Entity'),
	 ('CSF','Corporate Collective Investment Vehicle (CCIV) Sub-Fund');


INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (8,'2024-04-26','05:12:30','650664166','cdx-00007.gz',false),
	 (9,'2024-04-26','05:12:24','615337328','cdx-00008.gz',false),
	 (10,'2024-04-26','05:13:31','814120052','cdx-00009.gz',false),
	 (11,'2024-04-26','05:14:08','888668102','cdx-00010.gz',false),
	 (12,'2024-04-26','05:13:00','736093278','cdx-00011.gz',false),
	 (13,'2024-04-26','05:14:53','966070312','cdx-00012.gz',false),
	 (14,'2024-04-26','05:13:49','782085582','cdx-00013.gz',false),
	 (15,'2024-04-26','05:13:17','727733154','cdx-00014.gz',false),
	 (16,'2024-04-26','05:12:36','625579859','cdx-00015.gz',false),
	 (17,'2024-04-26','05:12:49','627747897','cdx-00016.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (18,'2024-04-26','05:13:25','711433284','cdx-00017.gz',false),
	 (19,'2024-04-26','05:12:47','654480339','cdx-00018.gz',false),
	 (20,'2024-04-26','05:14:26','744302229','cdx-00019.gz',false),
	 (21,'2024-04-26','05:14:17','803290877','cdx-00020.gz',false),
	 (22,'2024-04-26','05:13:29','585920779','cdx-00021.gz',false),
	 (23,'2024-04-26','05:14:26','698072638','cdx-00022.gz',false),
	 (24,'2024-04-26','05:15:10','790837228','cdx-00023.gz',false),
	 (25,'2024-04-26','05:13:57','640777904','cdx-00024.gz',false),
	 (26,'2024-04-26','05:16:41','980932385','cdx-00025.gz',false),
	 (27,'2024-04-26','05:14:19','705409340','cdx-00026.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (28,'2024-04-26','05:15:28','846025598','cdx-00027.gz',false),
	 (29,'2024-04-26','05:15:16','829564076','cdx-00028.gz',false),
	 (30,'2024-04-26','05:15:11','799835189','cdx-00029.gz',false),
	 (31,'2024-04-26','05:15:14','816055629','cdx-00030.gz',false),
	 (32,'2024-04-26','05:14:41','742689214','cdx-00031.gz',false),
	 (33,'2024-04-26','05:14:19','702900099','cdx-00032.gz',false),
	 (34,'2024-04-26','05:14:35','703169617','cdx-00033.gz',false),
	 (35,'2024-04-26','05:14:11','646001131','cdx-00034.gz',false),
	 (36,'2024-04-26','05:14:27','698491641','cdx-00035.gz',false),
	 (37,'2024-04-26','05:15:17','788115871','cdx-00036.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (38,'2024-04-26','05:14:28','688426381','cdx-00037.gz',false),
	 (39,'2024-04-26','05:15:07','780057110','cdx-00038.gz',false),
	 (40,'2024-04-26','05:15:06','745165913','cdx-00039.gz',false),
	 (41,'2024-04-26','05:20:03','1484055087','cdx-00040.gz',false),
	 (42,'2024-04-26','05:14:51','747666086','cdx-00041.gz',false),
	 (43,'2024-04-26','05:15:31','817804113','cdx-00042.gz',false),
	 (44,'2024-04-26','05:15:11','777572726','cdx-00043.gz',false),
	 (45,'2024-04-26','05:15:48','826360966','cdx-00044.gz',false),
	 (46,'2024-04-26','05:14:21','681531900','cdx-00045.gz',false),
	 (47,'2024-04-26','05:15:01','776983471','cdx-00046.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (48,'2024-04-26','05:14:43','716156517','cdx-00047.gz',false),
	 (49,'2024-04-26','05:14:49','715626855','cdx-00048.gz',false),
	 (50,'2024-04-26','05:14:36','702324104','cdx-00049.gz',false),
	 (51,'2024-04-26','05:15:07','778367843','cdx-00050.gz',false),
	 (52,'2024-04-26','05:14:46','732652458','cdx-00051.gz',false),
	 (53,'2024-04-26','05:16:10','863855458','cdx-00052.gz',false),
	 (54,'2024-04-26','05:17:09','1035140453','cdx-00053.gz',false),
	 (55,'2024-04-26','05:14:22','634531849','cdx-00054.gz',false),
	 (56,'2024-04-26','05:14:30','705544043','cdx-00055.gz',false),
	 (57,'2024-04-26','05:14:03','619774980','cdx-00056.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (58,'2024-04-26','05:14:24','662820773','cdx-00057.gz',false),
	 (59,'2024-04-26','05:15:08','764399015','cdx-00058.gz',false),
	 (60,'2024-04-26','05:14:26','671847309','cdx-00059.gz',false),
	 (61,'2024-04-26','05:15:48','819430915','cdx-00060.gz',false),
	 (62,'2024-04-26','05:13:22','528179183','cdx-00061.gz',false),
	 (63,'2024-04-26','05:16:00','886928355','cdx-00062.gz',false),
	 (64,'2024-04-26','05:16:24','910248393','cdx-00063.gz',false),
	 (65,'2024-04-26','05:15:19','803586399','cdx-00064.gz',false),
	 (66,'2024-04-26','05:15:11','768024183','cdx-00065.gz',false),
	 (67,'2024-04-26','05:13:50','599789227','cdx-00066.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (68,'2024-04-26','05:16:15','881204264','cdx-00067.gz',false),
	 (69,'2024-04-26','05:15:36','817515136','cdx-00068.gz',false),
	 (70,'2024-04-26','05:15:22','782690259','cdx-00069.gz',false),
	 (71,'2024-04-26','05:16:08','877866623','cdx-00070.gz',false),
	 (72,'2024-04-26','05:14:07','595467292','cdx-00071.gz',false),
	 (73,'2024-04-26','05:15:19','766196306','cdx-00072.gz',false),
	 (74,'2024-04-26','05:15:32','816832613','cdx-00073.gz',false),
	 (75,'2024-04-26','05:15:39','820836177','cdx-00074.gz',false),
	 (76,'2024-04-26','05:16:31','901060809','cdx-00075.gz',false),
	 (77,'2024-04-26','05:15:42','814656849','cdx-00076.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (78,'2024-04-26','05:15:26','754457555','cdx-00077.gz',false),
	 (79,'2024-04-26','05:15:35','792482701','cdx-00078.gz',false),
	 (80,'2024-04-26','05:14:35','675637372','cdx-00079.gz',false),
	 (81,'2024-04-26','05:14:47','674016331','cdx-00080.gz',false),
	 (82,'2024-04-26','05:15:32','805513363','cdx-00081.gz',false),
	 (83,'2024-04-26','05:16:20','915698179','cdx-00082.gz',false),
	 (84,'2024-04-26','05:15:45','805289234','cdx-00083.gz',false),
	 (85,'2024-04-26','05:15:21','725859088','cdx-00084.gz',false),
	 (86,'2024-04-26','05:16:10','865460756','cdx-00085.gz',false),
	 (87,'2024-04-26','05:15:54','820524672','cdx-00086.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (88,'2024-04-26','05:15:11','727256912','cdx-00087.gz',false),
	 (89,'2024-04-26','05:17:25','962603304','cdx-00088.gz',false),
	 (90,'2024-04-26','05:16:01','846662193','cdx-00089.gz',false),
	 (91,'2024-04-26','05:15:20','784637639','cdx-00090.gz',false),
	 (92,'2024-04-26','05:15:21','744578102','cdx-00091.gz',false),
	 (93,'2024-04-26','05:16:22','880626677','cdx-00092.gz',false),
	 (94,'2024-04-26','05:14:30','632403904','cdx-00093.gz',false),
	 (95,'2024-04-26','05:14:45','690165569','cdx-00094.gz',false),
	 (96,'2024-04-26','05:15:44','765468683','cdx-00095.gz',false),
	 (97,'2024-04-26','05:14:40','670834780','cdx-00096.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (98,'2024-04-26','05:15:57','828358264','cdx-00097.gz',false),
	 (99,'2024-04-26','05:15:02','720841058','cdx-00098.gz',false),
	 (100,'2024-04-26','05:14:58','716653634','cdx-00099.gz',false),
	 (101,'2024-04-26','05:16:03','837452360','cdx-00100.gz',false),
	 (102,'2024-04-26','05:15:59','805178864','cdx-00101.gz',false),
	 (103,'2024-04-26','05:16:07','806657877','cdx-00102.gz',false),
	 (104,'2024-04-26','05:15:01','690294371','cdx-00103.gz',false),
	 (105,'2024-04-26','05:14:57','688960189','cdx-00104.gz',false),
	 (106,'2024-04-26','05:14:34','637129639','cdx-00105.gz',false),
	 (107,'2024-04-26','05:15:10','712134938','cdx-00106.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (108,'2024-04-26','05:15:26','735390875','cdx-00107.gz',false),
	 (109,'2024-04-26','05:15:27','736680213','cdx-00108.gz',false),
	 (110,'2024-04-26','05:14:45','672231783','cdx-00109.gz',false),
	 (111,'2024-04-26','05:15:01','713654635','cdx-00110.gz',false),
	 (112,'2024-04-26','05:15:31','777248705','cdx-00111.gz',false),
	 (113,'2024-04-26','05:16:20','820502431','cdx-00112.gz',false),
	 (114,'2024-04-26','05:17:14','947558025','cdx-00113.gz',false),
	 (115,'2024-04-26','05:17:10','911680013','cdx-00114.gz',false),
	 (116,'2024-04-26','05:16:27','867093344','cdx-00115.gz',false),
	 (117,'2024-04-26','05:14:43','660320011','cdx-00116.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (118,'2024-04-26','05:15:39','747109553','cdx-00117.gz',false),
	 (119,'2024-04-26','05:14:45','650172147','cdx-00118.gz',false),
	 (120,'2024-04-26','05:15:59','783749748','cdx-00119.gz',false),
	 (121,'2024-04-26','05:14:52','648666519','cdx-00120.gz',false),
	 (122,'2024-04-26','05:16:56','896772299','cdx-00121.gz',false),
	 (123,'2024-04-26','05:15:15','700129836','cdx-00122.gz',false),
	 (124,'2024-04-26','05:16:27','937789759','cdx-00123.gz',false),
	 (125,'2024-04-26','05:15:19','668339136','cdx-00124.gz',false),
	 (126,'2024-04-26','05:14:44','672003433','cdx-00125.gz',false),
	 (127,'2024-04-26','05:15:33','713371643','cdx-00126.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (128,'2024-04-26','05:16:33','821560330','cdx-00127.gz',false),
	 (129,'2024-04-26','05:16:50','858291105','cdx-00128.gz',false),
	 (130,'2024-04-26','05:16:42','831731259','cdx-00129.gz',false),
	 (131,'2024-04-26','05:15:27','712166990','cdx-00130.gz',false),
	 (132,'2024-04-26','05:17:03','874365736','cdx-00131.gz',false),
	 (133,'2024-04-26','05:14:23','549112747','cdx-00132.gz',false),
	 (134,'2024-04-26','05:16:25','796040767','cdx-00133.gz',false),
	 (135,'2024-04-26','05:16:03','732189201','cdx-00134.gz',false),
	 (136,'2024-04-26','05:16:11','766427284','cdx-00135.gz',false),
	 (137,'2024-04-26','05:17:13','889446987','cdx-00136.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (138,'2024-04-26','05:16:53','839174660','cdx-00137.gz',false),
	 (139,'2024-04-26','05:16:56','851350230','cdx-00138.gz',false),
	 (140,'2024-04-26','05:16:06','759353241','cdx-00139.gz',false),
	 (141,'2024-04-26','05:14:18','610257624','cdx-00140.gz',false),
	 (142,'2024-04-26','05:16:09','818489054','cdx-00141.gz',false),
	 (143,'2024-04-26','05:16:46','858508082','cdx-00142.gz',false),
	 (144,'2024-04-26','05:16:16','707662382','cdx-00143.gz',false),
	 (145,'2024-04-26','05:16:31','739217301','cdx-00144.gz',false),
	 (146,'2024-04-26','05:18:02','807387850','cdx-00145.gz',false),
	 (147,'2024-04-26','05:18:15','816875674','cdx-00146.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (148,'2024-04-26','05:17:52','755810632','cdx-00147.gz',false),
	 (149,'2024-04-26','05:18:06','773784871','cdx-00148.gz',false),
	 (150,'2024-04-26','05:19:01','886203299','cdx-00149.gz',false),
	 (151,'2024-04-26','05:16:52','673133546','cdx-00150.gz',false),
	 (152,'2024-04-26','05:18:17','758629332','cdx-00151.gz',false),
	 (153,'2024-04-26','05:19:25','1054889535','cdx-00152.gz',false),
	 (154,'2024-04-26','05:19:18','734296640','cdx-00153.gz',false),
	 (155,'2024-04-26','05:18:43','748285077','cdx-00154.gz',false),
	 (156,'2024-04-26','05:18:47','659631245','cdx-00155.gz',false),
	 (157,'2024-04-26','05:19:05','785677491','cdx-00156.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (158,'2024-04-26','05:18:12','606938438','cdx-00157.gz',false),
	 (159,'2024-04-26','05:19:38','733388205','cdx-00158.gz',false),
	 (160,'2024-04-26','05:18:45','708543249','cdx-00159.gz',false),
	 (161,'2024-04-26','05:19:48','721718810','cdx-00160.gz',false),
	 (162,'2024-04-26','05:20:03','755293429','cdx-00161.gz',false),
	 (163,'2024-04-26','05:20:21','754670587','cdx-00162.gz',false),
	 (164,'2024-04-26','05:19:19','724027919','cdx-00163.gz',false),
	 (165,'2024-04-26','05:20:19','745500900','cdx-00164.gz',false),
	 (166,'2024-04-26','05:19:57','799754198','cdx-00165.gz',false),
	 (167,'2024-04-26','05:20:28','753151696','cdx-00166.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (168,'2024-04-26','05:19:49','683367748','cdx-00167.gz',false),
	 (169,'2024-04-26','05:20:15','739837700','cdx-00168.gz',false),
	 (170,'2024-04-26','05:17:52','551260801','cdx-00169.gz',false),
	 (171,'2024-04-26','05:20:10','690583839','cdx-00170.gz',false),
	 (172,'2024-04-26','05:19:48','628343311','cdx-00171.gz',false),
	 (173,'2024-04-26','05:21:53','872973869','cdx-00172.gz',false),
	 (174,'2024-04-26','05:20:30','752391767','cdx-00173.gz',false),
	 (175,'2024-04-26','05:21:11','853113259','cdx-00174.gz',false),
	 (176,'2024-04-26','05:20:09','647523672','cdx-00175.gz',false),
	 (177,'2024-04-26','05:20:50','759735557','cdx-00176.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (178,'2024-04-26','05:20:42','715295619','cdx-00177.gz',false),
	 (179,'2024-04-26','05:20:18','688187927','cdx-00178.gz',false),
	 (180,'2024-04-26','05:20:46','779470489','cdx-00179.gz',false),
	 (181,'2024-04-26','05:21:42','863420942','cdx-00180.gz',false),
	 (182,'2024-04-26','05:21:21','813720603','cdx-00181.gz',false),
	 (183,'2024-04-26','05:20:08','650115235','cdx-00182.gz',false),
	 (184,'2024-04-26','05:20:00','639878673','cdx-00183.gz',false),
	 (185,'2024-04-26','05:19:42','600415331','cdx-00184.gz',false),
	 (186,'2024-04-26','05:20:31','709050632','cdx-00185.gz',false),
	 (187,'2024-04-26','05:21:31','826431876','cdx-00186.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (188,'2024-04-26','05:20:05','643025146','cdx-00187.gz',false),
	 (189,'2024-04-26','05:20:37','730771702','cdx-00188.gz',false),
	 (190,'2024-04-26','05:21:09','769944046','cdx-00189.gz',false),
	 (191,'2024-04-26','05:21:04','764133508','cdx-00190.gz',false),
	 (192,'2024-04-26','05:20:29','707982329','cdx-00191.gz',false),
	 (193,'2024-04-26','05:20:44','708563145','cdx-00192.gz',false),
	 (194,'2024-04-26','05:19:04','463011838','cdx-00193.gz',false),
	 (195,'2024-04-26','05:19:33','539354411','cdx-00194.gz',false),
	 (196,'2024-04-26','05:24:42','1126900044','cdx-00195.gz',false),
	 (197,'2024-04-26','05:20:03','732754705','cdx-00196.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (198,'2024-04-26','05:20:45','734319853','cdx-00197.gz',false),
	 (199,'2024-04-26','05:19:27','551393175','cdx-00198.gz',false),
	 (200,'2024-04-26','05:22:13','863764583','cdx-00199.gz',false),
	 (201,'2024-04-26','05:22:14','894527197','cdx-00200.gz',false),
	 (202,'2024-04-26','05:22:27','891971232','cdx-00201.gz',false),
	 (203,'2024-04-26','05:21:24','786829860','cdx-00202.gz',false),
	 (204,'2024-04-26','05:22:42','944159651','cdx-00203.gz',false),
	 (205,'2024-04-26','05:20:26','611047336','cdx-00204.gz',false),
	 (206,'2024-04-26','05:19:23','518535734','cdx-00205.gz',false),
	 (207,'2024-04-26','05:24:49','1029497387','cdx-00206.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (208,'2024-04-26','05:20:58','696397171','cdx-00207.gz',false),
	 (209,'2024-04-26','05:21:37','802991671','cdx-00208.gz',false),
	 (210,'2024-04-26','05:20:48','702359653','cdx-00209.gz',false),
	 (211,'2024-04-26','05:22:00','874516586','cdx-00210.gz',false),
	 (212,'2024-04-26','05:21:32','768954653','cdx-00211.gz',false),
	 (213,'2024-04-26','05:22:18','887917406','cdx-00212.gz',false),
	 (214,'2024-04-26','05:22:06','781814490','cdx-00213.gz',false),
	 (215,'2024-04-26','05:21:01','697736383','cdx-00214.gz',false),
	 (216,'2024-04-26','05:20:54','656719496','cdx-00215.gz',false),
	 (217,'2024-04-26','05:21:05','696791028','cdx-00216.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (218,'2024-04-26','05:21:45','739671049','cdx-00217.gz',false),
	 (219,'2024-04-26','05:23:47','1002174000','cdx-00218.gz',false),
	 (220,'2024-04-26','05:21:47','740566356','cdx-00219.gz',false),
	 (221,'2024-04-26','05:21:02','706311619','cdx-00220.gz',false),
	 (222,'2024-04-26','05:21:00','717657178','cdx-00221.gz',false),
	 (223,'2024-04-26','05:21:45','749762998','cdx-00222.gz',false),
	 (224,'2024-04-26','05:22:00','795797678','cdx-00223.gz',false),
	 (225,'2024-04-26','05:21:43','784521524','cdx-00224.gz',false),
	 (226,'2024-04-26','05:21:19','707515568','cdx-00225.gz',false),
	 (227,'2024-04-26','05:22:40','879663994','cdx-00226.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (228,'2024-04-26','05:21:10','670869811','cdx-00227.gz',false),
	 (229,'2024-04-26','05:22:01','831129467','cdx-00228.gz',false),
	 (230,'2024-04-26','05:21:21','704994933','cdx-00229.gz',false),
	 (231,'2024-04-26','05:22:57','894157160','cdx-00230.gz',false),
	 (232,'2024-04-26','05:20:28','595349247','cdx-00231.gz',false),
	 (6,'2024-04-26','05:12:09','801172104','cdx-00005.gz',false),
	 (7,'2024-04-26','05:13:53','849866138','cdx-00006.gz',false),
	 (1,'2024-04-26','05:11:49','763235321','cdx-00000.gz',true),
	 (2,'2024-04-26','05:10:38','546233894','cdx-00001.gz',true),
	 (3,'2024-04-26','05:12:16','819861650','cdx-00002.gz',true);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (4,'2024-04-26','05:11:37','740626189','cdx-00003.gz',true),
	 (5,'2024-04-26','05:12:50','934923495','cdx-00004.gz',false),
	 (233,'2024-04-26','05:23:33','1001364911','cdx-00232.gz',false),
	 (234,'2024-04-26','05:22:29','807415486','cdx-00233.gz',false),
	 (235,'2024-04-26','05:22:14','851572500','cdx-00234.gz',false),
	 (236,'2024-04-26','05:22:55','882331878','cdx-00235.gz',false),
	 (237,'2024-04-26','05:22:30','817860660','cdx-00236.gz',false),
	 (238,'2024-04-26','05:21:47','786182463','cdx-00237.gz',false),
	 (239,'2024-04-26','05:22:19','822299685','cdx-00238.gz',false),
	 (240,'2024-04-26','05:21:06','682026041','cdx-00239.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (241,'2024-04-26','05:21:30','706849867','cdx-00240.gz',false),
	 (242,'2024-04-26','05:21:55','724932955','cdx-00241.gz',false),
	 (243,'2024-04-26','05:21:58','754457144','cdx-00242.gz',false),
	 (244,'2024-04-26','05:20:18','518930234','cdx-00243.gz',false),
	 (245,'2024-04-26','05:21:12','634401980','cdx-00244.gz',false),
	 (246,'2024-04-26','05:21:45','738799872','cdx-00245.gz',false),
	 (247,'2024-04-26','05:20:59','595286131','cdx-00246.gz',false),
	 (248,'2024-04-26','05:21:17','619741321','cdx-00247.gz',false),
	 (249,'2024-04-26','05:23:00','831777915','cdx-00248.gz',false),
	 (250,'2024-04-26','05:22:58','817082321','cdx-00249.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (251,'2024-04-26','05:21:51','731516861','cdx-00250.gz',false),
	 (252,'2024-04-26','05:22:02','709900977','cdx-00251.gz',false),
	 (253,'2024-04-26','05:21:13','605081273','cdx-00252.gz',false),
	 (254,'2024-04-26','05:20:50','546564007','cdx-00253.gz',false),
	 (255,'2024-04-26','05:22:03','699140174','cdx-00254.gz',false),
	 (256,'2024-04-26','05:20:40','773262579','cdx-00255.gz',false),
	 (257,'2024-04-26','05:23:10','835934656','cdx-00256.gz',false),
	 (258,'2024-04-26','05:21:41','632686472','cdx-00257.gz',false),
	 (259,'2024-04-26','05:21:22','606520921','cdx-00258.gz',false),
	 (260,'2024-04-26','05:23:18','1172992328','cdx-00259.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (261,'2024-04-26','05:22:58','828109444','cdx-00260.gz',false),
	 (262,'2024-04-26','05:23:09','853087356','cdx-00261.gz',false),
	 (263,'2024-04-26','05:22:25','761531918','cdx-00262.gz',false),
	 (264,'2024-04-26','05:24:19','1054731700','cdx-00263.gz',false),
	 (265,'2024-04-26','05:23:46','899907852','cdx-00264.gz',false),
	 (266,'2024-04-26','05:22:26','748028792','cdx-00265.gz',false),
	 (267,'2024-04-26','05:22:55','826806584','cdx-00266.gz',false),
	 (268,'2024-04-26','05:23:00','1117922669','cdx-00267.gz',false),
	 (269,'2024-04-26','05:23:19','822402614','cdx-00268.gz',false),
	 (270,'2024-04-26','05:22:59','792627686','cdx-00269.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (271,'2024-04-26','05:22:21','692754802','cdx-00270.gz',false),
	 (272,'2024-04-26','05:23:24','835514605','cdx-00271.gz',false),
	 (273,'2024-04-26','05:23:30','797361335','cdx-00272.gz',false),
	 (274,'2024-04-26','05:21:02','730652238','cdx-00273.gz',false),
	 (275,'2024-04-26','05:23:07','747353421','cdx-00274.gz',false),
	 (276,'2024-04-26','05:21:19','744130427','cdx-00275.gz',false),
	 (277,'2024-04-26','05:23:59','873502209','cdx-00276.gz',false),
	 (278,'2024-04-26','05:24:39','983403802','cdx-00277.gz',false),
	 (279,'2024-04-26','05:23:45','835079786','cdx-00278.gz',false),
	 (280,'2024-04-26','05:24:17','852529014','cdx-00279.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (281,'2024-04-26','05:23:11','908792806','cdx-00280.gz',false),
	 (282,'2024-04-26','05:22:45','691842478','cdx-00281.gz',false),
	 (283,'2024-04-26','05:23:50','847779334','cdx-00282.gz',false),
	 (284,'2024-04-26','05:23:13','737002602','cdx-00283.gz',false),
	 (285,'2024-04-26','05:23:23','741393085','cdx-00284.gz',false),
	 (286,'2024-04-26','05:21:59','678025564','cdx-00285.gz',false),
	 (287,'2024-04-26','05:25:27','1081702644','cdx-00286.gz',false),
	 (288,'2024-04-26','05:23:58','861298180','cdx-00287.gz',false),
	 (289,'2024-04-26','05:24:20','865965718','cdx-00288.gz',false),
	 (290,'2024-04-26','05:23:06','695609685','cdx-00289.gz',false);
INSERT INTO mds.ccrwl_index_2024_18 (id,index_upload_date,index_upload_time,size_bytes,file_name,is_processed) VALUES
	 (291,'2024-04-26','05:23:16','711608602','cdx-00290.gz',false),
	 (292,'2024-04-26','05:24:20','887141453','cdx-00291.gz',false),
	 (293,'2024-04-26','05:24:42','906948774','cdx-00292.gz',false),
	 (294,'2024-04-26','05:25:51','1049420298','cdx-00293.gz',false),
	 (295,'2024-04-26','05:25:42','934731969','cdx-00294.gz',false),
	 (296,'2024-04-26','05:24:03','725878821','cdx-00295.gz',false),
	 (297,'2024-04-26','05:24:18','671840181','cdx-00296.gz',false),
	 (298,'2024-04-26','05:25:34','938925262','cdx-00297.gz',false),
	 (299,'2024-04-26','05:25:01','694351014','cdx-00298.gz',false),
	 (300,'2024-04-26','05:25:10','853308879','cdx-00299.gz',false);
