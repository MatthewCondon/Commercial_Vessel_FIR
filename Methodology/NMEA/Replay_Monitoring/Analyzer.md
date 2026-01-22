# Overview
Analyzer is a decoder and viewer for live NMEA 2000 frames. It processes information from each PGN and turns it into a readable format, noting the type of message such as INFO and ERROR.

# Collecting Data
Use of analyzer requires live data collection from the NMEA backbone. 

A connection to the can0 interface must be established before data can be sent.
```
sudo ip link set can0 up type can bitrate 250000 restart-ms 100
```

The command to collect and save to an output file is:
```
candump can0 | candump2analyzer | analyzer > output.txt
```

# Interpreting Output
Data will be saved in the format seen below. There will be additional header information at the beginning of the file, but it can be ignored as it only relates to software production and copyright.

To analyze this information, focus on the PGN of interest and determine trends or frequency of frame. It is also beneficial to consider a large number of ERROR frames.

The command output is shown below:

```
INFO 2025-12-16T17:22:41.964Z [analyzer] Assuming normal format with one line per packet
INFO 2025-12-16T17:22:41.964Z [analyzer] New PGN 127488 for device 127 (heap 11183 bytes)
2025-12-16-17:22:41.964 2 127 255 127488 Engine Parameters, Rapid Update:  Instance = Single Engine or Dual Engine Port; Speed = 0.0 rpm; Boost Pressure = ERROR; Tilt/Trim = 0
INFO 2025-12-16T17:22:41.965Z [analyzer] New PGN 127489 for device 127 (heap 11216 bytes)
2025-12-16-17:22:41.966 2 127 255 127489 Engine Parameters, Dynamic:  Instance = Single Engine or Dual Engine Port; Oil pressure = 3.500 bar (50.76 PSI); Oil temperature = 25.45 C (77.8 F); Temperature = 25.40 C (77.7 F); Alternator Potential = 12.90 V; Fuel Rate = 10.5 L/h; Total Engine hours = 48003 s; Coolant Pressure = 0.500 bar (7.25 PSI); Fuel Pressure = 20 kPa; Discrete Status 1 =; Discrete Status 2 =; Percent Engine Load = 42; Percent Engine Torque = 75
INFO 2025-12-16T17:22:41.966Z [analyzer] New PGN 127493 for device 127 (heap 11231 bytes)
2025-12-16-17:22:41.967 2 127 255 127493 Transmission Parameters, Dynamic:  Instance = Single Engine or Dual Engine Port; Transmission Gear = Forward; Oil pressure = 3.500 bar (50.76 PSI); Oil temperature = 87.95 C (190.3 F); Discrete Status 1 = 0
2025-12-16-17:22:41.968 2 127 255 127488 Engine Parameters, Rapid Update:  Instance = Dual Engine Starboard; Speed = 0.0 rpm; Boost Pressure = 0.000 bar (0.00 PSI); Tilt/Trim = 0
INFO 2025-12-16T17:22:41.969Z [analyzer] New PGN 129025 for device 243 (heap 22414 bytes)
2025-12-16-17:22:41.969 2 243 255 129025 Position, Rapid Update:  Latitude = Unknown; Longitude = Unknown
2025-12-16-17:22:41.970 2 127 255 127489 Engine Parameters, Dynamic:  Instance = Dual Engine Starboard; Oil pressure = 3.500 bar (50.76 PSI); Oil temperature = 25.45 C (77.8 F); Temperature = 25.40 C (77.7 F); Alternator Potential = 12.90 V; Fuel Rate = 10.5 L/h; Total Engine hours = 0 s; Coolant Pressure = 0.500 bar (7.25 PSI); Fuel Pressure = 20 kPa; Discrete Status 1 =; Discrete Status 2 =; Percent Engine Load = 80; Percent Engine Torque = 75
2025-12-16-17:22:41.971 2 127 255 127493 Transmission Parameters, Dynamic:  Instance = Dual Engine Starboard; Transmission Gear = Forward; Oil pressure = 3.500 bar (50.76 PSI); Oil temperature = 87.95 C (190.3 F); Discrete Status 1 = 0
2025-12-16-17:22:41.972 2 127 255 127488 Engine Parameters, Rapid Update:  Instance = 2; Speed = 0.0 rpm; Boost Pressure = 0.000 bar (0.00 PSI); Tilt/Trim = Unknown
2025-12-16-17:22:41.974 2 127 255 127489 Engine Parameters, Dynamic:  Instance = 2; Oil pressure = 3.500 bar (50.76 PSI); Oil temperature = 25.45 C (77.8 F); Temperature = 25.40 C (77.7 F); Alternator Potential = 12.90 V; Fuel Rate = 10.5 L/h; Total Engine hours = 0 s; Coolant Pressure = 0.500 bar (7.25 PSI); Fuel Pressure = 20 kPa; Discrete Status 1 =; Discrete Status 2 =; Percent Engine Load = 80; Percent Engine Torque = 75
2025-12-16-17:22:41.974 2 127 255 127488 Engine Parameters, Rapid Update:  Instance = 3; Speed = 0.0 rpm; Boost Pressure = 0.000 bar (0.00 PSI); Tilt/Trim = Unknown
2025-12-16-17:22:41.977 2 127 255 127489 Engine Parameters, Dynamic:  Instance = 3; Oil pressure = 3.500 bar (50.76 PSI); Oil temperature = 25.45 C (77.8 F); Temperature = 25.40 C (77.7 F); Alternator Potential = 12.90 V; Fuel Rate = 10.5 L/h; Total Engine hours = 0 s; Coolant Pressure = 0.500 bar (7.25 PSI); Fuel Pressure = 20 kPa; Discrete Status 1 =; Discrete Status 2 =; Percent Engine Load = 80; Percent Engine Torque = 75
INFO 2025-12-16T17:22:41.977Z [analyzer] New PGN 127245 for device 127 (heap 22429 bytes)
2025-12-16-17:22:41.977 2 127 255 127245 Rudder:  Instance = 0; Direction Order = No Order; Angle Order = Unknown; Position = 0.0 deg
INFO 2025-12-16T17:22:41.995Z [analyzer] New PGN 127250 for device 127 (heap 22444 bytes)
2025-12-16-17:22:41.996 2 127 255 127250 Vessel Heading:  SID = Unknown; Heading = 126.1 deg; Deviation = Unknown; Variation = Unknown; Reference = Magnetic
INFO 2025-12-16T17:22:41.996Z [analyzer] New PGN 129026 for device 127 (heap 22459 bytes)
2025-12-16-17:22:41.997 2 127 255 129026 COG & SOG, Rapid Update:  SID = Unknown; COG Reference = True; COG = 40.0 deg; SOG = Unknown
INFO 2025-12-16T17:22:41.997Z [analyzer] New PGN 128267 for device 127 (heap 22474 bytes)
2025-12-16-17:22:41.997 3 127 255 128267 Water Depth:  SID = Unknown; Depth = 100.00 m; Offset = 0.000 m; Range = Unknown
INFO 2025-12-16T17:22:42.019Z [analyzer] New PGN 127258 for device 34 (heap 33657 bytes)
2025-12-16-17:22:42.019 6  34 255 127258 Magnetic Variation:  SID = Unknown; Source = Unknown; Age of service = Unknown; Variation = -13.7 deg
2025-12-16-17:22:42.025 2 127 255 127250 Vessel Heading:  SID = Unknown; Heading = 133.2 deg; Deviation = Unknown; Variation = Unknown; Reference = True
2025-12-16-17:22:42.025 2 127 255 127250 Vessel Heading:  SID = Unknown; Heading = 126.1 deg; Deviation = 0.0 deg; Variation = 7.1 deg; Reference = Magnetic
INFO 2025-12-16T17:22:42.025Z [analyzer] New PGN 129025 for device 127 (heap 33672 bytes)
2025-12-16-17:22:42.026 2 127 255 129025 Position, Rapid Update:  Latitude = 41.7736551; Longitude = -71.4851741
INFO 2025-12-16T17:22:42.039Z [analyzer] New PGN 129027 for device 127 (heap 33687 bytes)
2025-12-16-17:22:42.040 2 127 255 129027 Position Delta, Rapid Update:  SID = Unknown; Time Delta = 28693; Latitude Delta = 14; Longitude Delta = 4159
INFO 2025-12-16T17:22:42.040Z [analyzer] New PGN 129291 for device 127 (heap 33702 bytes)
2025-12-16-17:22:42.040 2 127 255 129291 Set & Drift, Rapid Update:  SID = Unknown; Set Reference = True; Set = 40.0 deg; Drift = 14.20 m/s
INFO 2025-12-16T17:22:42.040Z [analyzer] New PGN 127251 for device 127 (heap 33717 bytes)
2025-12-16-17:22:42.041 2 127 255 127251 Rate of Turn:  SID = Unknown; Rate = 0.00000 deg/s
INFO 2025-12-16T17:22:42.041Z [analyzer] New PGN 127252 for device 127 (heap 33732 bytes)
2025-12-16-17:22:42.041 3 127 255 127252 Heave:  SID = Unknown; Heave = 2.30 m
INFO 2025-12-16T17:22:42.042Z [analyzer] New PGN 130306 for device 127 (heap 33747 bytes)
2025-12-16-17:22:42.042 2 127 255 130306 Wind Data:  SID = Unknown; Wind Speed = 4.80 m/s; Wind Angle = 112.0 deg; Reference = True (ground referenced to North)
2025-12-16-17:22:42.043 2 127 255 130306 Wind Data:  SID = 0; Wind Speed = 16.33 m/s; Wind Angle = 283.0 deg; Reference = Apparent
2025-12-16-17:22:42.055 2 127 255 127488 Engine Parameters, Rapid Update:  Instance = Single Engine or Dual Engine Port; Speed = 0.0 rpm; Boost Pressure = ERROR; Tilt/Trim = 0

```
