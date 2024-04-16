# Import required modules 
import sys
import pandas as pd

# Read excel file as a pandas dataframe, using openpyxl as the engine (xlrd does not support xlsx files)
df = pd.read_excel('File.xlsx', sheet_name=5, engine='openpyxl')

# Get unique temperature values using unique function
temps = df["Temperature"].unique()

print(temps)

# Empty list to put the filtered data in
filteredData = []

# Use boolean indexing to obtain data at specific temperatures
for temp in range(len(temps)):
    data = df.loc[df["Temperature"] == temps[temp]]
    lastData = data.iloc[-1:] # Get the last row, as this is what is of interest
    filteredData.append(lastData) # Append to the list

filtered_df = pd.concat(filteredData) # Concatenate the list of dataframes

filtered_df.to_excel("ExtractedData.xlsx")