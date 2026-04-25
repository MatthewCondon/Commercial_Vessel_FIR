# Summary
Though Wireshark is primarily used for network traffic analysis, it can be configured to analyze CAN, NMEA 0183, and NMEA 2000 data.

Ensure all [Wireshark Files](/Methodology/NMEA/Frame_Analysis/Wireshark_Files) have been placed in your Wireshark folders. The lua files must be placed at:
```
C:\Users\____\AppData\Roaming\Wireshark\
```
Then, restart Wireshark or reload the lua files. In Wireshark, this can be completed by going to:
```
Analyze > Reload Lua Plugins
```
You can also do this using ```Ctrl + Shift + L```

# After Configurations
After installing the necessary scripts and files, enable all protocols on Wireshark. Go to:
```
Analyze > Enabled Protocols > Enable All
```
