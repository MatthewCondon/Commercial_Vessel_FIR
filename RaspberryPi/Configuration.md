# **Hardware**

## Products

In order to conduct any analysis on the NMEA 2000 Network, it is necessary to configure a Raspberry Pi with NMEA Hat.

When conducting our analysis of the NMEA 2000 Vessel Simulator, we used the following hardware:
- Raspberry https://copperhilltech.com/pican-m-nmea-0183-nmea-2000-hat-for-raspberry-pi/

<center><img width="500" alt="image" src="https://github.com/user-attachments/assets/cb3574d2-6b94-4899-9415-9115c67e0be5" /></center>


- Pi + Hat Case: https://copperhilltech.com/metal-enclosure-for-pican-m-and-raspberry-pi-4/

<img width="500" alt="image" src="https://github.com/user-attachments/assets/dafb64e9-8f75-4b61-9134-bf21aa1c3a99" />

## Cable Management
  
It is also important to have the proper cable for connection to the NMEA 2000 Network backbone. The Hat connects to this using a NMEA 2000 CAN-Bus cable. There is no need to use a USB-C power cable for the Raspberry Pi, as NMEA cables have dedicated one of the prongs to supply power to any attached unit.


<img width="500" alt="image" src="https://github.com/user-attachments/assets/11078809-ca95-456a-9683-19db843fce35" />

The purpose of each prong is shown in the below image:

<img width="500" alt="image" src="https://github.com/user-attachments/assets/1894c956-07bd-43c7-b07e-782f17a705ca" />


# **Raspberry Pi Configuration**
The actual documentation for installation is found at the below link:
https://copperhilltech.com/content/pican-m_UGB_30.pdf


