# Overview
When analyzing a ECDIS or VEGA Computer, the file system will likely be different from a general-use system. The below folders were identified during methodology development that detail information and files that may exist in the system.

# Directory Structure

## Announcements
Contains system announcements, messages, bulletins, and warnings.

- Look for unusual or spoofed system messages.
- Can show evidence of system tampering or unusual alerts.

---

## Bin
Executable binaries or utility files used by VEGA.

- Check for unauthorized EXE/DLL files.
- Look for altered timestamps or non-original binaries.

---

## Bsb_Files
Raster chart packages (BSB/KAP format).

- Look for altered or replaced navigation charts.
- Invalid or manipulated charts can be used maliciously.

---

## Chart1_Files
ENC configuration files and Chart 1 reference charts.

- Detect changes to symbol definitions or color tables.
- Manipulating Chart 1 could mislead operators.

---

## Charting
Includes general charting support files, configuration references.

- Check for modified settings that alter chart display.
- Investigate suspicious route behavior.

---

## ChartInstallation
Tracks installed charts and chart loading history.

- Look for unusual chart updates or installations.
- Useful to detect unauthorized charts being added.

---

## CID
Chart Information Database. Helps confirm what charts were expected vs. present.

- Compare to Enc_Files to detect missing chart data.

---

## ColorFiles
Defines color palettes for day/dusk/night modes.

- Rarely modified, but a tampered color table could hide hazards.

---

## Cursors
Cursor symbol images and UI elements.

- Large count may indicate custom graphical assets.
- Look for suspicious embedded images (malware sometimes hides here).

---

## DefaultNavCompSymbols
Navigation components symbol library (buoys, lights, etc.).

- Tampering could alter displayed hazards or aids to navigation.
- Check for replaced or malformed icons.

---

## DgpsStations
Differential GPS correction stations data.

- Check if fake or foreign stations were injected.
- Could indicate attempts to distort positioning.

---

## EC1_ED1
Specialized navigation symbol sets or chart data.

- Look for tampered visualization elements.
- Could mislead route planning.

---

## Enc_Files
ENC (S-57/S-63) vector chart files.

One of the most critical locations.

Look for:

- Modified ENCs  
- Backdated timestamps  
- Missing or altered cells  
- Copies replaced with older/newer versions  

---

## GeoSym
Core geopositioning symbols.

- Altering these can distort how hazards, land, or depths are displayed.

---

## GeoSym_Files
Extended symbols or alternate symbols.

- Compare against original reference to spot changes.

---

## GeoTransData
Geospatial transformation tables, datums, offsets.

- High-value target for attacks aiming to shift charted positions.
- Look for modified datum shift values.

---

## Help
Local help files, often HTML or XML.

- Malware sometimes hides in help folders.
- Check for scripts or unexpected file types.

---

## HydrographicPublications
Sailing Directions, List of Lights, T&P Notices, etc.

- Look for altered publications.
- Check timestamps for evidence of tampering.

---

## IEnc_Files
Inland ENC files (IENC charts).

- Same risk as ENC files — chart manipulation.

---

## Images
UI images, chart symbols, textures, icons.

Large count makes this a possible hiding spot for:

- Steganographic payloads  
- Malicious embedded metadata  
- Replaced navigation icons  
