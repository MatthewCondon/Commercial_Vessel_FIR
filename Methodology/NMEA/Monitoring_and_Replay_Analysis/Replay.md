# Summary
Using the Raw SocketCAN format, you can replay historical data on all vessel display devices.

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

# Sending Frames
After the data has been collected in or converted to the Raw SocketCAN format, it can be sent back into the vessel network using ```canplayer```:
```
canplayer -I file.log -t
```
At this point, the boat displays will begin replaying data. All display systems will show the relevant information from the log file.
