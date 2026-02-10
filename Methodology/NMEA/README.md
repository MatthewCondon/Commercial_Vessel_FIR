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

### Data Conversions
When working with historical and live NMEA 2000 data, investigators may need to reference the [Conversions Table](/Methodology/NMEA/Data_Conversions/NMEA2000_Conversions.md). Different programs in the NMEA Methodology rely on different data types.

## Anomalous Behavior
To identify if an anomaly exists during Vessel Replay or Vessel Monitoring:
- **Identify devices not sending PGNs or sending corrupted data** - displays will drop this data
- **Identify PGNs sending 2+ data frames at the same instant with different data** - displays will drop this data
- **Identify abnormal movements or actions on vessel display systems** - this includes large changes in GPS, jumps in sensor readings, or no data being received - displays will either drop this data or switch between shown data

To identify if an anomaly exists in the HMM Classifier Model...

To identify if an anomaly exists in the PGN-Specific Scripts...
