# 0183 PCAP Analysis
This directory contains information on conducting 0183 PCAP Analysis. Data must be in the traditional NMEA 0183 format. It can be collected in different ways.

Use that file with ```0183toPCAP.py``` to get a PCAP file that can be parsed with Wireshark.

## Wireshark I/O Graphs
**Follow the below instructions to create custom I/O Graphs.** These will allow you to visually view the PGNs sent throughout the PCAP files. Complete the dissector steps before this form of analysis.

```Statistics > I/O Graphs > + ( Add a new graph )```

Now, complete the following steps:
1. Disable all other graphs and enable the new one.
2. Name the graph for the PGN it is analyzing. In the example below, heading was used.
3. Apply a filter for the PGN of interest. In the example below, 127250 was used. The filter was **nmea-2000.pgn == 127250**
4. Update the style of the graph. Effective styles are **Line** and **Graph**.
5. Wait a few moments for the graph to update.

The interval is automatically set to 1 second. Adjust this as necessary depending on the send rate of the inspected PGN.


# 2000 PCAP Analysis
This directory contains information on conducting 2000 PCAP analysis. Data must be in the Raw SocketCAN format. It can be collected using the below command:

```
candump -L can0 > output.txt
```

Use output.txt with the ```2000can2pcap.py``` in accordance with directions of the sub-directories.

## Wireshark I/O Graphs
**Follow the below instructions to create custom I/O Graphs.** These will allow you to visually view the PGNs sent throughout the PCAP files. Complete the dissector steps before this form of analysis.

```Statistics > I/O Graphs > + ( Add a new graph )```

Now, complete the following steps:
1. Disable all other graphs and enable the new one.
2. Name the graph for the PGN it is analyzing. In the example below, heading was used.
3. Apply a filter for the PGN of interest. In the example below, 127250 was used. The filter was **nmea-2000.pgn == 127250**
4. Update the style of the graph. Effective styles are **Line** and **Graph**.
5. Wait a few moments for the graph to update.

The interval is automatically set to 1 second. Adjust this as necessary depending on the send rate of the inspected PGN.
