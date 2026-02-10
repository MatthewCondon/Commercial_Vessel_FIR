# Wireshark Files
These actions require Raw SocketCAN data from the vessel, and cannot be completed on the Raspberry Pi.

## Wireshark NMEA Dissector
These files must be in the Wireshark plugins folder:

```C:\Users\User\AppData\Roaming\Wireshark\plugins```

Use ```maritime-modules``` and ```maritime-dissector.lua```

Then, restart Wireshark or reload the lua files.

```Analyze > Reload Lua Plugins```

This can be achieved using ```Ctrl + Shift + L```

## Maritime-N2K.Zip
This zip file is an optional configuration set for additional information shown in Wireshark.

Use ```Maritime-N2K.zip```

This does not need to be located in any specific folder.

```Edit > Configuration Profiles > Import > From Zip File...```

## After-Installation
After installing the necessary scripts and files, enable all protocols on Wireshark.

```Analyze > Enabled Protocols > Enable All```
