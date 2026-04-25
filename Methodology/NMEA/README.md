# NMEA Analysis
## Background
The background information for NMEA can be found at [NMEA Background](/Background/NMEA).

## Incident Response Actions
When conducting Incident Response and Analysis, complete the following steps in the provided order:
- **Determine if any historical NMEA 2000 data may be accessed**
  - Connect the Raspberry Pi to the vessel backbone using the [Raspberry Pi Instructions](/Tools/Raspberry_Pi)
  - Conduct [Vessel Replay](/Methodology/NMEA/Historical_Replay.md)
  - Detect anomalous behavior using the [HMM Classifier Model](/Methodology/NMEA/Classifier)
  - Investigate specific PGN anomalies using the [PGN-Specific Scripts](/Methodology/NMEA/Anomalous_PGN_Scripts)
- **Determine if any live NMEA 2000 data may be accessed**
  - Connect the Raspberry Pi to the vessel backbone using the [Raspberry Pi Instructions](/Tools/Raspberry_Pi)
  - Conduct live [Vessel Monitoring](/Methodology/NMEA/Live_Monitoring.md)
  - Collect at least 10 minutes of data
    - Detect anomalous behavior using the [HMM Classifier Model](/Methodology/NMEA/Classifier)
    - Investigate specific PGN anomalies using the [PGN-Specific Scripts](/Methodology/NMEA/Anomalous_PGN_Scripts)
- **Used in either case**
  - Analyze PCAP files for CAN traffic patterns on the NMEA backbone using [can2pcap](/Methodology/NMEA/PCAP_Analysis/can2pcap.py)

## Notes
The HMM Classifier Model was focused on experimenting with machine learning to assist the anomaly detection analysis. It is incomplete due to a lack of data and requires further training/development before deployment.
