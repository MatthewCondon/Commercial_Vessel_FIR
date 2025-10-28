# National Marine Electronics Association (NMEA) 0183/2000
Many older vessels employ NMEA 0183, the original standard for electronic communication between onboard systems. Designed to establish a unified method of data exchange, it relied on ASCII-based messaging that allowed a single device to transmit information to multiple listeners. While simple and effective for its time, the network’s point-to-point wiring and restriction to one transmitting device at a time greatly limited its scalability and data throughput. As vessels became more advanced and reliant on interconnected systems, these constraints led to the development and eventual adoption of NMEA 2000 as the modern industry standard.

NMEA 2000 builds upon the foundation of NMEA 0183 by introducing a Controller Area Network (CAN)–based architecture that allows multiple devices, or nodes, to communicate simultaneously over a shared data bus. This design enables higher data transfer speeds, reduced wiring complexity, and improved network reliability. Every node can both transmit and receive information, creating a dynamic and efficient system capable of supporting a wide range of sensors, displays, and control units. Additionally, its plug-and-play interoperability allows devices from different manufacturers to integrate seamlessly, enhancing system flexibility and ease of installation.

At the core of NMEA 2000 lies the CAN bus protocol—originally developed for automotive systems but later adapted for marine applications. The CAN bus operates through three key components: the microcontroller, CAN controller, and CAN transceiver. The microcontroller manages message interpretation and transmission logic, the CAN controller handles data encoding and error detection, and the transceiver converts digital signals for transmission along the physical network. This structure makes CAN lightweight, efficient, and cost-effective while prioritizing critical data to minimize latency and transmission errors. By leveraging this technology, NMEA 2000 provides vessels with a robust, high-speed communication backbone that connects all essential navigation and monitoring systems into a cohesive digital network.

The NMEA 2000 network connects to individual devices using drop cables directly plugged into the backbone. These cables are responsible for carrying power and data between nodes. As a result of this architecture, the data can be broadcast across the network so that all devices can passively monitor relevant information. This enables future scalability of the system, so new devices may be added with minimal configuration. This includes additional devices such as computers.

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

This can be exported directly for Excel for further analysis.
