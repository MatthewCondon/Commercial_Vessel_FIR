# YDVR-04N Extraction
## Summary
This section is focused on extracting data from the YDVR-04N model. This VDR is generally seen on smaller craft and allows for extraction of raw NMEA 2000 frames.

## Method 1 - Software Extraction
### Step 1: Software Download
Download the [Extraction Software](https://www.yachtd.com/downloads/YDVRCONV.zip)

Unzip the zip file to the local file system.

The software works on the below Operating Systems:
- Windows
- Linux
- OS X / macOS

A usage manual is included in the zip file.

### Step 2: Software Usage
Depending on the host Operating System, a local defender/antivirus may think the extraction software is harmful. Disregard this warning and run the software.

#### Page 1: Welcome to YDVR Converter
The necessary format to use this software is **.DAT**.

#### Page 2: Select Source Files
Locate the .DAT files in the local file system and upload them to the software.
**Note:** a completed .DAT file will be approximately 2,500 KB (usually 2,560 KB). The last file was be less than this amount.

#### Page 3: Select Output File Type
Select one of the 7 main file types:
- **GPS Tracks**: GPX File
- **GPS Coordinates**: CSV File
- **Printable Log Book**: ODT File
- **OpenSkipper**: XML File
- **CanBoat / Signal K**: LOG File
- **CAN Data**: LOG File
- **NMEA Devices List**: CSV File

#### Page 4: Output File Settings
Select _Browse_ and determine where to place the output file in the local file system.

Choose any other relevant settings for the investigation. Generally, processing all data in the source files is effective for analysis.

#### Page 5: Final Check
Confirm extraction settings are correct.

Upon selecting _Next_, a progress bar will appear. Wait for it to complete.

### Page 6: Done!
Select _Finish_ to save the downloaded output file.

## Method 2 - DAT Reverse Engineering
### Step 1: Script
Utilize the script at [Location for extraction script]

To run the script, enter the below command:
```
insert command
```

### Step 2: Expected Output
The output will produce two files:
1. 
2. 
