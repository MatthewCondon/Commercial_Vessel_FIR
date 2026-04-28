# Summary
This file contains information on conducting NMEA 0183 analysis in Wireshark. Data must be in the traditional NMEA 0183 format, which can be collected from multiple sources.

```
2026-9-8 13:00:00 UTC | $ERALR,130103.52,C04,A,A,NORMAL*3E
2026-9-8 13:00:00 UTC | $ERALR,124154.62,C14,A,V,NORMAL*20
2026-9-8 13:00:00 UTC | $ERALR,010335.94,L11,A,A,NORMAL*23
2026-9-8 13:00:00 UTC | $GPRMB,A,5.19,L,WPT001,WPT002,4006.4952,N,07403.4727,W,008.3,178,002.3,V*6B
2026-9-8 13:00:00 UTC | $GPZTG,124327,,*4F
2026-9-8 13:00:00 UTC | $GPGGA,124328,4006.4952,N,07403.4727,W,1,04,2.5,0010,M,-033,M,,*51
```

First, put the NMEA 0183 into PCAP format using the necessary [script](/Methodology/NMEA/Conversion_Scripts/NMEA0183/0183_to_PCAP.py). Then, open the PCAP file in Wireshark.

## Wireshark I/O Graphs
Using I/O graphs allows you to view important information, including data values and packet frequency. These will allow you to visually view the data sent throughout the PCAP files. Go to:
```
Statistics > I/O Graphs > + (add a new graph)
```
Now, complete the following steps:
- Disable all other graphs and enable the new one.
- Name the graph for the data filter you are analyzing.
- Apply a filter for the data of interest. For example, course over ground use: **nmea_decoded.rmc.sog**.
- Update the style of the graph. Effective styles are **Line** and **Graph**.
- In the Y Field, place a designated filter for what data you want to view. You may be able to use the same filter with a Y Axis of MAX to view values. Otherwise, select a Y Field of Packets to view frequency at which data is sent.
- Select **Reset**.

The interval is automatically set to 1 second. Adjust this as necessary depending on the send rate of the inspected data.
