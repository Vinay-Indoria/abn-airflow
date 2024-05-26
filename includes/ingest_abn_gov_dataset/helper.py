from datetime import datetime
from lxml import etree
import os, logging
import pandas as pd
from includes.utils import ( adapt_value, batch_insert_postgres )


def parse_abn_xml(abr_elem, current_file_name):
    is_replaced = True if abr_elem.get('replaced').strip() == 'Y' else False   
    last_updated_elem = abr_elem.get('recordLastUpdatedDate')   
    if last_updated_elem is not None:
        try:
            # Convert to datetime object if the format is YYYYMMDD
            last_updated = datetime.strptime(last_updated_elem, '%Y%m%d').date()
        except ValueError:
            last_updated = None
    else:
        last_updated = None
    abn = int(abr_elem.find('ABN').text.strip())
    abn_status = abr_elem.find('ABN').get('status')
    abn_status_from_date_elem = abr_elem.find('ABN').get('ABNStatusFromDate')
    if abn_status_from_date_elem is not None:
        try:
            # Convert to datetime object if the format is YYYYMMDD
            abn_status_from_date = datetime.strptime(abn_status_from_date_elem, '%Y%m%d').date()
        except ValueError:
            abn_status_from_date = None
    else:
        abn_status_from_date = None
    business_type_code = abr_elem.find('EntityType/EntityTypeInd').text
    
    if business_type_code.strip() == 'IND':
        business_name = None
        name_title_elem = abr_elem.find('LegalEntity/IndividualName/NameTitle')
        if name_title_elem is not None:
            name_title = abr_elem.find('LegalEntity/IndividualName/NameTitle').text
        else:
            name_title = None
        given_name_elem = abr_elem.find('LegalEntity/IndividualName/GivenName')
        if given_name_elem is not None:
            given_name = abr_elem.find('LegalEntity/IndividualName/GivenName').text
        else:
            given_name = None
        family_name_elem = abr_elem.find('LegalEntity/IndividualName/FamilyName')
        if family_name_elem is not None:
            family_name = abr_elem.find('LegalEntity/IndividualName/FamilyName').text
        else:
            family_name = None
        entity_type_code = abr_elem.find('LegalEntity/IndividualName').get('type')
        business_state = abr_elem.find('LegalEntity/BusinessAddress/AddressDetails/State').text
        business_postcode = abr_elem.find('LegalEntity/BusinessAddress/AddressDetails/Postcode').text
        is_individual = True
    else:
        business_name = abr_elem.find('MainEntity/NonIndividualName/NonIndividualNameText').text
        name_title = None
        given_name = None
        family_name = None
        entity_type_code = abr_elem.find('MainEntity/NonIndividualName').get('type')
        business_state = abr_elem.find('MainEntity/BusinessAddress/AddressDetails/State').text
        business_postcode = abr_elem.find('MainEntity/BusinessAddress/AddressDetails/Postcode').text
        is_individual = False
    
    gst = abr_elem.find('GST').text
    gst_status = abr_elem.find('GST').get('status')
    gst_from_date_elem = abr_elem.find('GST').get('GSTStatusFromDate')
    if gst_from_date_elem is not None:
        try:
            # Convert to datetime object if the format is YYYYMMDD
            gst_from_date = datetime.strptime(gst_from_date_elem, '%Y%m%d').date()
        except ValueError:
            gst_from_date = None
    else:
        gst_from_date = None
    
    return (abn, abn_status, abn_status_from_date, business_type_code, business_name, name_title, given_name, family_name, entity_type_code, business_state, business_postcode, is_individual, gst, gst_status, gst_from_date, current_file_name, is_replaced, last_updated)

def parse_abn_dgr_xml(abn, dgr_elem, current_file_name):
    dgr_business_name = dgr_elem.find('NonIndividualName/NonIndividualNameText').text
    if dgr_business_name is None or dgr_business_name.strip() == "":
        return None
    dgr_type = dgr_elem.find('NonIndividualName').get('type')
    dgr_status_from_date_elem = dgr_elem.get('DGRStatusFromDate')
    if dgr_status_from_date_elem is not None:
        try:
            # Convert to datetime object if the format is YYYYMMDD
            dgr_status_from_date = datetime.strptime(dgr_status_from_date_elem, '%Y%m%d').date()
        except ValueError:
            dgr_status_from_date = None
    else:
        dgr_status_from_date = None
    return (abn, dgr_type, dgr_business_name, dgr_status_from_date, current_file_name)

def parse_and_load_xml(file_path, **kwargs):
    current_file_name = os.path.basename(file_path)
    
    abr_data = []
    dgr_data = []
    other_en_data = []
    # Open the XML file for parsing
    context = etree.iterparse(file_path, events=('end',), tag='ABR')
    
    for event, abr_elem in context:
        abn = int(abr_elem.find('ABN').text.strip())
        abr_parsed_resp = parse_abn_xml(abr_elem, current_file_name)
        abr_data.append(abr_parsed_resp)

        for dgr_elem in abr_elem.findall('DGR'):
            dgr_parsed_resp = parse_abn_dgr_xml(abn, dgr_elem, current_file_name)
            if dgr_parsed_resp:
                dgr_data.append(dgr_parsed_resp)

        for other_elem in abr_elem.findall('OtherEntity'):
            other_business_name = other_elem.find('NonIndividualName/NonIndividualNameText').text
            other_type = other_elem.find('NonIndividualName').get('type')
            if other_business_name is not None or other_business_name.strip() != "":
                other_en_data.append((abn, other_type, other_business_name, current_file_name))
        
        # Clean up the element to free memory
        abr_elem.clear()
        while abr_elem.getprevious() is not None:
            del abr_elem.getparent()[0]

    return abr_data, dgr_data, other_en_data


def insert_raw_abr_data(abr_data):
    insert_sql = """
    INSERT INTO raw.abn_bulk_data (abn, abn_status, abn_status_from_date, business_type_code, business_name, name_title, given_name, family_name, entity_type_code, business_state, business_postcode, is_individual, gst, gst_status, gst_from_date, file_name, is_replaced, last_record_updated_date) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    batch_insert_postgres(insert_sql, abr_data)


def insert_raw_dgr_data(dgr_data):
    insert_sql = """
    INSERT INTO raw.abn_dgr_bulk_data (abn, type_code, business_name, dgr_status_from_date, file_name) VALUES (%s, %s, %s, %s, %s)
    """
    batch_insert_postgres(insert_sql, dgr_data)

def insert_raw_other_entity_data(other_entity_data):
    insert_sql = """
    INSERT INTO raw.abn_other_entity_bulk_data (abn, type_code, business_name, file_name) VALUES (%s, %s, %s, %s)
    """
    batch_insert_postgres(insert_sql, other_entity_data)

