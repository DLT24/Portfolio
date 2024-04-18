# Import required modules 
import sys
import pandas as pd
import glob
import numpy

# Define function: get unique values, excluding NaN values
def unique_no_nan(x):
    return x.dropna().unique()

# Path to files
path = r"C:\Users\Username\Downloads\*"

# Files in path
file_list = glob.glob(path + "Filename-*")

# Empty list for dataframes of each file
excel_list = []

# Read one excel at a time in a loop
# Insert new column with filename in each file
# This is done instead of reading all excel files at once, as later on when using boolean indexing it is not possible to ref the df in list (list[df] does not work)
for file in file_list:
    df = pd.read_excel(file, sheet_name=5, engine='openpyxl')
    df.insert(0, 'Name', f"{file}")

    # Empty lists to put temperatures and filtered data in
    temps = []
    filteredData = []

    # Get unique temps using defined function
    temps = unique_no_nan(df["Temperature"])

    # Ensure temp values are integers, not floats
    temps = temps.astype(numpy.int64) 
    print(temps)

    # Use boolean indexing to obtain data at specific temps
    for temp in range(len(temps)):
        data = df.loc[df["Temperature"] == temps[temp]]
        lastData = data.iloc[-1:] # Get the last row
        filteredData.append(lastData) # Append to the list

    filtered_df = pd.concat(filteredData) # Concatenate the list of dataframes for 1 file, into 1 df
    excel_list.append(filtered_df) # Append the df for 1 file to a list, to get the list of dfs

allData = pd.concat(excel_list, ignore_index=True) # Concatenate the list of dfs
allData.to_excel("ExtractedData.xlsx") # Export to excel
