# Forensic Analysis of Maritime Cyber Events

## MARINA Framework
_A Framework for Maritime Incident & Network Analysis_

This GitHub repository contains all TTPs for USCG CPTs to employ during cyber forensic analysis in maritime environments. The information contained is to assist operators in determining risk or likelihood of a cyberattack and is focused on assisting the decision-making process.

<p align="center">
  <img src="/Images/MARINA_Flow.png" alt="MarINA Logo" width="70%">
</p>


## Table of Contents
### Background
- [Voyage Data Recorder Background](/Background/VDR)
- [NMEA Background](/Background/NMEA)
- [Triage Background](/Background/Triage)

### Methodology
- [Proactive vs Reactive Analysis](/Methodology/README.md)
- [Voyage Data Recorder Methodology & Scripts](/Methodology/VDR)
- [NMEA Methodology & Scripts](/Methodology/NMEA)
- [Triage Methodology & Scripts](/Methodology/Triage)

### Tools
- [Raspberry Pi Forensic Computer](/Tools/Raspberry_Pi/)
- [FTK Imager](/Tools/FTK_Imager)
- [Autopsy](/Tools/Autopsy)
- [Miscellaneous Tools](/Tools/Data_Viewers/)


## Decision Tree
When responding to a maritime cyber incident, it is important that certain steps be taken to maximize response efforts.

<p align="center">
  <img src="/Images/FlowChart.png" alt="Decision Tree Flow Chart" width="60%">
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

The capstone advisor was LT Kaitlyn DeValk-Hammond.
