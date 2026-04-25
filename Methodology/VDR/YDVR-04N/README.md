# YDVR-04N / Yacht Devices Voyage Recorder
## Information
### Relevant Manuals
User Manual: https://www.yachtd.com/downloads/ydvr04.pdf

### Relevant Software
DAT File Converter: https://www.yachtd.com/downloads/YDVRCONV.zip

## Data Extraction
### Software Deconstruction
Download the DAT File Converter software for the applicable Operating System (Windows, Linux, OS X / macOS). Depending on the host system, a local defender/antivirus may flag the software as harmful. Disregard this warning and run the program.

**Page 1: Welcome to YDVR Converter**
The necessary format for this software is a .DAT file.

**Page 2: Select Source Files**
Local the .DAT files in the local file system and upload them to the software. A completed .DAT file will be approximately 2,500 KB, with the last file being less than this amount.

**Page 3: Select Output File Type**
Select one of the 7 main file types:
- GPS Tracks: GPX File
- GPS Coordinates: CSV File
- Printable Log Book: ODT File
- OpenSkipper: XML File
- CanBoat / Signal K: LOG File
- CAN Data: LOG File
- NMEA Devices List: CSV File

**Page 4: Output File Settings**
Select _Browse_ and determine where to place the output file in the local system. Choose any other relevant settings for the investigation. Generally, processing all data in the source files is effective for analysis.

**Page 5: Final Check**
Confirm extraction settings are correct. Upon selecting _Next_, a progress bar will appear. Wait for it to complete.

**Page 6: Done!**
Select _Finish_ to save the downloaded output file. Repeat this process for additional output file types.

### VDR Manual Decoding
Navigate to the [DAT Decoder Script](/Methodology/VDR/YDVR-04N/DAT_Decoder.sh). To run the script, run the commands below:
```
chmd +x DAT_Extractor_To_Zip.sh
```
There are two ways to run the script:
```
./DAT_Extractor_To_Zip.sh 00010001.DAT --mode 1
./DAT_Extractor_To_Zip.sh 00010001.DAT --mode 2
```
### Step 2: Expected Output
The output will produce a ZIP file that contains three files, corresponding to each of the three main data formats used by NMEA networks:

1. 00010001_socketcan.log
2. 00010001_csv.csv
3. 00010001_decoded.txt

There is an additional output format to assist with organizing information.

## Data Analysis
After extracting the data, there are multiple tools for analysis.

### Software Deconstruction
**Format 1: Tracks - GPX File**
This is to view only the path, timestamps, and elevations that the vessel followed during the VDR's collection phase.

Use the [GPX Viewer](/Tools/Data_Viewers/VIEWGPX.md)

**Format 2: Spreadsheet - CSV File**
This is to view timestamps, longitude, and latitude that the vessel collected. Depending on how the VDR is configured, it may contain additional information that can be analyzed.

Use any form of Excel to analyze the data depending on what data is available.

**Format 3: Printable Log Book - ODT File**
These are log books that may have been completed on vessel systems and saved to the VDR.

Use Microsoft Word or another file viewer to analyze the data contained in these files.

**Format 4: OpenSkipper - XML File**
This format is used for the OpenSkipper format and contains further information on vessel activities.

Use the OpenSkipper application to view the data. It only works on Windows systems. The most recent version can be downloaded at the [OpenSkipper GitHub](https://github.com/OpenSkipper/OpenSkipper)

**Format 5: CanBoat / Signal K - LOG File**
This is raw NMEA 2000 data as if it were taken directly from the vessel backbone.

Use the canboat analyzer function from the [canboat GitHub](https://github.com/canboat/canboat).

**Format 6: CAN Data - LOG File**
This is a log format of the can data that was processed throughout the vessel, and is similar to a candump file format.

Replay this data using the [CAN Player Application](/Tools/Data_Viewers/CANVIEW.md)

**Format 7: NMEA Devices List - CSV File**
This is a list of all devices that communicated with the NMEA backbone at any point in the voyage. 

Analyze this information for any abnormal devices that should not be on the system or are not recognized.

### VDR Manual Decoding
If any raw NMEA can be extracted from the VDR or any other source, it is recommended to use any of the NMEA Analysis capabilities under [NMEA Methodology](/Methodology/NMEA).
