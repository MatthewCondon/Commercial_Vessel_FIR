# Summary
By connecting to the NMEA backbone, you can see the live data as it transmits throughout the vessel network.

# Setting the Interface
A connection to the interface is necessary to collect live data. Create the interface and set the necessary bit rate for NMEA 2000 networks. The restart occurs in the event an off-string is sent the network needs to be restarted.
```
sudo ip link set can0 up type can bitrate 250000 restart-ms 100
```

# Ensuring Interface Connection
Once the interface has been set, it is important to ensure it is ```UP``` and ready to process data with the Raspberry Pi.
```
ip -details link show can0
```
You should look for the following line in the command output:
```
4: can0: <NOARP,UP,LOWER_UP,ECHO> mtu 16 qdisc pfifo_fast state UP mode DEFAULT group default qlen 10
```

# Collecting Data
Data can be captured in multiple formats depending on user preference and investigation needs. The format and designated collection commands are below.

**Compact Human-Readable**
```
candump can0 > file.log
```

**Raw SocketCAN**
```
candump -L can0 > file.log
```

**Analzyer Format**
See [Analyzer Summary](/Methodology/NMEA/Conversion_Scripts/Analyzer.md)
