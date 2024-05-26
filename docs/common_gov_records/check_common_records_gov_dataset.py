import pandas as pd
import xml.etree.ElementTree as ET
import os

pub_11_path = 'abr_data_11.parquet'
pub_10_path = 'abr_data_10.parquet'

publ_df_11 = pd.read_parquet(pub_11_path)
publ_df_10 = pd.read_parquet(pub_10_path)

common_records = pd.merge(publ_df_11, publ_df_10, on='0')

print(common_records)

print(common_records.shape)
duplicate_abn_values = common_records['0'].unique()
duplicate_abn_set = set(duplicate_abn_values)
print(duplicate_abn_values)
print(len(duplicate_abn_values))

# Define the path to the XML file
file_path = '20240515_Public10.xml'

# Parse the XML file
tree = ET.parse(file_path)
root = tree.getroot()
print(root)

# List to keep track of elements to remove
elements_to_remove = []

# Iterate through all <ABR> elements within <Transfer>
for abr in root.findall('ABR'):
    abn_element = abr.find('ABN')
    if abn_element is not None and int(abn_element.text.strip()) in duplicate_abn_set:
        elements_to_remove.append(abr)

print('----------------------------------------------')
print(len(elements_to_remove))
print('----------------------------------------------')
# Remove identified elements
for elem in elements_to_remove:
    root.remove(elem)

# Save the modified XML back to the file
tree.write(file_path, encoding='utf-8', xml_declaration=True)

os.remove('duplicate_abn_public_10_xml.txt')
# Write array to a text file
with open('duplicate_abn_public_10_xml.txt', 'w') as f:
    for item in duplicate_abn_values:
        f.write(f"{item}\n")

print('DONE')