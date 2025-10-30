# NMEA_VDR_FIR
This repository contains:
- Background information on CAN/NMEA 2000, Voyage Data Recorder, and Computer System Triage
- Raspberry Pi Configuration for NMEA 2000 Monitoring and Display
- Classifier Software Code
- TTPs for NMEA 2000 or VDR depending on what data investigators are working with
- Custom img File

## Set-Up
Before beginning forensic analysis of the vessel, it is essential to properly set up the investigative environment by installing all required tools and dependencies. The /Set_Up directory contains the installation packages, configuration files, and scripts necessary to prepare the system for analysis. This step ensures that all components—such as data parsers, log viewers, NMEA 2000 interpreters, and replay utilities—are correctly configured and ready to interface with the vessel’s data sources. Proper installation from the /Set_Up directory minimizes compatibility issues, enables consistent tool performance, and establishes a reliable foundation for subsequent stages of forensic examination, including data acquisition, parsing, and replay of Voyage Data Recorder (VDR) information.

## Flow Chart
![Capstone Flow Chart (3)](https://github.com/user-attachments/assets/6afc04dc-f46f-4404-9c0b-54c6b54d69b2)

### Data Hierarchy
The importance of data is:
1. Voyage Data Recorder
2. NMEA-2000
3. Computer Triage

# Contributions
This Commercial Vessel FIR SOP was developed by 1/c Matthew Condon, 1/c James Kang, 1/c Cassandra Moshy, and 1/c Ryan Von Weihe during the 2025-2026 USCGA academic year.

The capstone advisor was LT DeValk-Hammond.
