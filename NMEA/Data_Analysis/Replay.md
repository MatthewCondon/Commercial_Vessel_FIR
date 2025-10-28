# Replaying Live CAN Data
The purpose of this section is to reproduce CAN Data and run it through the NMEA 2000 backbone to emulate a vessel voyage. Replay works with Raw SocketCAN Data.
```
(1759512073.077585) can0 09F20540#00FCAC0D1B0E00FF
```


## Setting Replay Frame Count
Assuming the interface has already been configured in accordance with Monitoring.md, it is necessary to set the number of frames replay will send.
```
sudo ip link set can0 txqueuelen 10000
```
This command has no output associated with it.

## Sending Frames to NMEA
The command necessary for data replay is canplayer. As previously stated, all lines need to be in Raw SocketCAN data format in order for the NMEA Network to accept the frames. Then, place the frames into a designated file. Finally, run the replay command.
```
canplayer -I file.log -t
```
While there is not explicitly any associated output for this command, Linux will not restart the current prompt. The user will be brought to a stdin feed. Do not enter any information during this time.

The boat should begin replaying data at this time.
