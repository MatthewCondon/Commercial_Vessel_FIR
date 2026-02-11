# YDVR-04N Analysis
## Summary
This section os focused on methods of reviewing data that has been extracted from the YDVR-04N model. To analyze this data, custom scripts have been provided or software can be installed that is produced by Yacht Devices or found online.

## Step 1: Software Download
Many tools that can be used during analysis of the YDVR-04N can be found in [Tools](/Tools/Data_Viewers/).

Steps to acquire files for analysis can be found in [YDVR-04N Extraction](/Methodology/VDR/Model_Specific_Analysis/YDVR-04N/Extraction.md).

## Step 2: Data Analysis
### Format 1: Tracks - GPX File
This is to view only the path, timestamps, and elevations that the vessel followed during the VDR's collection phase.

Use the [GPX Viewer](/Tools/Data_Viewers/VIEWGPX.md)

### Format 2: Spreadsheet - CSV File
This is to view timestamps, longitude, and latitude that the vessel collected. Depending on how the VDR is configured, it may contain additional information that can be analyzed.

Use any form of Excel to analyze the data depending on what data is available.

### Format 3: Printable Log Book - ODT File
These are log books that may have been completed on vessel systems and saved to the VDR.

Use Microsoft Word or another file viewer to analyze the data contained in these files.

### Format 4: OpenSkipper - XML File
This format is used for the OpenSkipper format and contains further information on vessel activities.

Use the OpenSkipper application to view the data. It only works on Windows systems. The most recent version can be downloaded at the [OpenSkipper GitHub](https://github.com/OpenSkipper/OpenSkipper)

### Format 5: CanBoat / Signal K - LOG File
This is raw NMEA 2000 data as if it were taken directly from the vessel backbone.

Use the canboat analyzer function from the [canboat GitHub](https://github.com/canboat/canboat).

### Format 6: CAN Data - LOG File
This is a log format of the can data that was processed throughout the vessel, and is similar to a candump file format.

Replay this data using the [CAN Player Application](/Tools/Data_Viewers/CANVIEW.md)

### Format 7: NMEA Devices List - CSV File
This is a list of all devices that communicated with the NMEA backbone at any point in the voyage. 

Analyze this information for any abnormal devices that should not be on the system or are not recognized.
