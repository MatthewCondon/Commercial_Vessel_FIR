# National Marine Electronics Association (NMEA) 0183/2000
Many older vessels employ NMEA 0183, an older version of the network. The initial purpose for this model was to serve as the first implementation of standardized communications between electronic equipment onboard a ship. Using ASCII-based data exchange, it enabled one device to actively transmit data on the network to multiple listening devices. Despite involving an easy implementation process, only allowing one device to transmit at a time limited the amount of data that could be shared at any given time. Furthermore, the wiring was point-to-point between devices rather than along a data bus across the vessel. As a result of these limitations, NMEA 2000 was created and later adopted as the industry standard. Though it is still used in some vessels, it has largely been phased out due to NMEA 2000.

NMEA 2000 builds upon the foundation of NMEA 0183 by adopting a Controller Area Network (CAN) architecture that allows multiple devices to communicate simultaneously over a single shared data bus. This network enables faster data transmission, reduced wiring complexity, and improved reliability. Each device, or node, can both transmit and receive information, making the system far more efficient and scalable. The standard also supports plug-and-play interoperability between sensors, displays, and control units, ensuring consistent performance across a wide range of marine electronics.

The underlying protocol of NMEA networks is the CAN Bus. Initially designed for automobiles, it was later adopted for vessel communication systems. The CAN Bus operates using three main components: microcontroller, CAN controller, and CAN transceiver. The microcontroller is responsible for interpreting received messages and determining what messages to send to the network. The CAN controller is responsible for the encoding and error detection processes. Lastly, the CAN transceiver connects the controller to the physical wire, turning data into signals to pass. CAN bus offers many benefits to vehicles since it is a lightweight process, simple to implement and inexpensive. It also provides easy access and monitoring due to a single point-of-entry into the network. Finally, it is a very efficient process. Important data is prioritized on the bus, minimizing interruption and errors. CAN now serves as the basis of NMEA 2000 technology, enabling maritime sensors and equipment to simultaneously communicate throughout a vessel network.



# Data Formats
There are three formats for data that investigators need to work with.


## Raw SocketCAN
This data is the format required to send data back onto the NMEA 2000 Network for emulation. This format is necessary for the ```canplayer``` tool.
```
(1759499866.954945) can0 09F90B40#FFFC001B8C05FFFF
(1759499866.959004) can0 09F11340#FF00000000FFFFFF
(1759499866.959594) can0 0DF11440#FFE600FFFFFFFFFF
(1759499866.963717) can0 09FD0240#FFD0075D07F8FFFF
(1759499866.964286) can0 09FD0240#00F40C3E9202FFFF
(1759499866.975399) can0 09F20040#000000000000
(1759499866.977543) can0 09F20540#00FCAC0D1B0E00FF
(1759499866.978075) can0 09F20040#010000000000
(1759499866.978888) can0 09F8012B#FFFFFF7FFFFFFF7F
(1759499866.980579) can0 09F20540#01FCAC0D1B0E00FF
```

## Compact Human-Readable
This is the output from using the ```candump``` tool installed on the Raspberry Pi.
```
  can0  19FA0601   [8]  E0 0F 80 7F 17 59 17 A8
  can0  19FA0601   [8]  E1 02 00 00 8C 15 60 09
  can0  19FA0601   [8]  E2 5E 1B FF FF FF FF FF
  can0  19FA0B01   [8]  E0 0F 80 F6 00 59 17 A8
  can0  19FA0B01   [8]  E1 02 00 00 8C 15 60 09
  can0  19FA0B01   [8]  E2 5E 1B FF FF FF FF FF
  can0  0DF0102B   [8]  AD FF FF FF FF FF FF FF
  can0  09F8012B   [8]  FF FF FF 7F FF FF FF 7F
  can0  09F8022B   [8]  AD FC FF FF FF FF FF FF
  can0  18FF0449   [8]  89 98 00 01 00 00 FF FF
```

## CSV Analyzer Format
Using the ```candump2analyzer``` tool on the Raspberry Pi, this format decodes the hex into decimal notation for easier readability.
```
2025-09-30-23:35:19.356,2,127250,64,255,8,ff,69,00,ff,7f,ff,7f,fc
2025-09-30-23:35:19.356,5,130311,41,255,8,77,c3,ff,ff,ff,7f,ff,ff
2025-09-30-23:35:19.356,2,127250,64,255,8,ff,01,f1,00,00,d7,04,fd
2025-09-30-23:35:19.356,2,129025,64,255,8,e0,32,f5,19,78,10,ac,d5
2025-09-30-23:35:19.356,2,129027,64,255,8,ff,15,85,0e,00,92,10,00
2025-09-30-23:35:19.356,2,129291,64,255,8,ff,fc,00,1b,8c,05,ff,ff
2025-09-30-23:35:19.356,2,127251,64,255,8,ff,00,00,00,00,ff,ff,ff
2025-09-30-23:35:19.356,3,127252,64,255,8,ff,e6,00,ff,ff,ff,ff,ff
2025-09-30-23:35:19.356,2,127488,64,255,8,01,00,00,ff,ff,7f,ff,ff
2025-09-30-23:35:19.356,2,130306,64,255,8,ff,f1,0c,11,0f,fa,ff,ff
```
