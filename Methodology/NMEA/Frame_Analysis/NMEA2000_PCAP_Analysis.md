# Summary
This file contains information on conducting NMEA 0183 analysis in Wireshark. Data must be in the NMEA 2000 Raw SocketCAN format, which can be collected/converted from multiple sources.
```
(1765905989.266590) can0 09F8012B#FFFFFF7FFFFFFF7F
```

First, put the NMEA 2000 into PCAP format using the necessary [script](/Methodology/NMEA/Conversion_Scripts/NMEA2000/SocketCan_to_PCAP.py). Then, open the PCAP file in Wireshark.

## Wireshark I/O Graphs
Using I/O graphs allows you to view important information, including data values and packet frequency. These will allow you to visually view the data sent throughout the PCAP files. Go to:
```
Statistics > I/O Graphs > + (add a new graph)
```
Now, complete the following steps:
- Disable all other graphs and enable the new one.
- Name the graph for the data filter you are analyzing.
- Apply a filter for the PGN of interest. For example, rudder use: **nmea-2000-127245**.
- Update the style of the graph. Effective styles are **Line** and **Graph**.
- In the Y Field, place a designated filter for what data you want to view. You may be able to use the same filter with a Y Axis of MAX to view values. Otherwise, select a Y Field of Packets to view frequency at which data is sent. For example, for the rudder's heading values use: **nmea-2000-127245.position**
- Select **Reset**.

The interval is automatically set to 1 second. Adjust this as necessary depending on the send rate of the inspected data.
