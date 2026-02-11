# Overview
When working with NMEA 2000 data, there are three formats that may be collected.

## Raw SocketCAN
```
(1765905989.266590) can0 09F8012B#FFFFFF7FFFFFFF7F
```

## Compact Human-Readable
```
can0  09F8012B   [8]  FF FF FF 7F FF FF FF 7F
```
## CSV
```
2025-12-16-17:22:40.967,2,129025,43,255,8,ff,ff,ff,7f,ff,ff,ff,7f
```

# Analyzer Format
An additional format may be used during collection of NMEA 2000 data. It can be found at [Analyzer](/Methodology/NMEA/Replay_Monitoring/Analyzer_Monitoring.md). This format cannot be translated into Raw SocketCAN, Compact Human-Readable, or CSV. However, it provides the data in a more structured and human-readable format, with additional information such as INFO and ERROR.


# Converting Data Formats
The relevant conversions for an investigation are shown below.

## Raw SocketCAN > CSV
```
candump2analyzer < CAN.log > CSV.log
```
_This command has no output associated with it._

Consider also using the [csv2socketcan script](/Methodology/NMEA/Data_Conversions/csv2socketcan.py]. The timing may be slightly off during replay but it may still be of use during PCAP investigations.

## Compact Human-Readable > Raw SocketCAN
_This must be transformed during the collection process._
```candump can0 | candump2analyzer```

## Raw SocketCAN > Analyzer
_This must be transformed during the collection process._
```candump can0 | candump2analyzer | analyzer```
