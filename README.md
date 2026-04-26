# Forensic Analysis of Maritime Cyber Events

## MARINA Framework
_Maritime Cyber Incident and Network Analysis Framework_

This GitHub repository serves as a framework for forensic analysis to be used by U.S. Coast Guard Cyber Protection Teams during investigations of commercial vessel networks. The information contained is designed to assist operators in determining risk or likelihood of a cyberattack and is focused on assisting the decision-making process. It consists of custom scripts, tools, and processes to better enable the forensic process. A flow chart is provided later that details how to use the tools and scripts provided in this repository.

<p align="center">
  <img src="/Images/MARinaName.png" alt="MarINA Logo" width="70%">
</p>


## Table of Contents
### Background
- [Voyage Data Recorder Background](/Background/VDR)
- [NMEA Background](/Background/NMEA)
- [Miscellaneous](/Background/Miscellaneous)

### Methodology
- [Analysis Approaches](/Methodology/README.md)
- [Voyage Data Recorder Models and Methodologies](/Methodology/VDR)
- [NMEA Methodology for Frame Analysis](/Methodology/NMEA/Frame_Analysis)
- [NMEA Methodology for Monitoring and Replay Analysis](/Methodology/NMEA/Monitoring_and_Replay_Analysis)
- [NMEA Methodology for Anomaly Detection](/Methodology/NMEA/Anomaly_Detection)
- [NMEA Methodology for Data Conversions](/Methodology/NMEA/Conversion_Scripts)

### Tools
- [Raspberry Pi Forensic Computer](/Tools/Raspberry_Pi/)
- [FTK Imager](/Tools/FTK_Imager)
- [Autopsy](/Tools/Autopsy)
- [Miscellaneous Tools](/Tools/Data_Viewers/)


## Decision Tree
When responding to a maritime cyber incident, it is important that certain steps be taken to maximize response efforts.

<p align="center">
  <img src="/Images/MARINA_Flow.png" alt="Decision Tree Flow Chart" width="60%">
</p>

### Data Hierarchy
The importance of data is:
1. Voyage Data Recorder
2. NMEA-2000
3. Computer Triage
4. Physical Analysis

_It is important that each step in the analysis occurs with all data types. The Flow Chart is designed to assist investigators during initial inquiries into a vessel._

# Contributions
The MarINA Framework was developed by 1/c Matthew Condon, 1/c James Kang, and 1/c Ryan Von Weihe during the 2025-2026 USCGA academic year.

We would like to acknowledge the following individuals who assisted with the successful completion of the project:
- Capstone Sponsors: LCDR Kenneth Miltenberger & LCDR Virgil Moreno
- Capstone Coordinators: LCDR Dahnyoung McGarry & LT Brandon Ledford
- Capstone Advisor LT Kaitlyn DeValk-Hammond
- CGCYBER Personnel: LTJG Joram Stith, LTJG James Campbell, LTJG Noah Soto & LTJG Chase Jin
- Cyber Systems Faculty & Staff
- USCGA Nautical Science Faculty & USCGA Waterfront Staff
