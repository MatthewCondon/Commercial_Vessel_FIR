# Settings and Configurations
The purpose of this section is to actively monitor live NMEA 2000 Data that is received in the form of candump frames.
```
  can0  09F11240   [8]  FF 69 00 FF 7F FF 7F FC
```

## Setting the Interface
Create the interface and set the necessary bit rate for NMEA 2000 networks. The restart occurs in the event an off-string is sent the network needs to be restarted.
```
sudo ip link set can0 up type can bitrate 250000 restart-ms 100
```
This command has no output associated with it.

## Ensure Interface is Up

Now that the interface is running, it is crucial to ensure it is live before running any CAN frames through the backbone.
```
ip -details link show can0
```
The associated output with this command is below:
```
4: can0: <NOARP,UP,LOWER_UP,ECHO> mtu 16 qdisc pfifo_fast state UP mode DEFAULT group default qlen 10
    link/can  promiscuity 0 minmtu 0 maxmtu 0
    can state ERROR-ACTIVE restart-ms 100
          bitrate 250000 sample-point 0.875
          tq 250 prop-seg 6 phase-seg1 7 phase-seg2 2 sjw 1
          mcp251x: tseg1 3..16 tseg2 2..8 sjw 1..4 brp 1..64 brp-inc 1
          clock 8000000 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```
We are looking to ensure that the state is UP.
