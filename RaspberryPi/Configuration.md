# **Hardware**

## Products

In order to conduct any analysis on the NMEA 2000 Network, it is necessary to configure a Raspberry Pi with NMEA Hat.

When conducting our analysis of the NMEA 2000 Vessel Simulator, we used the following hardware:
- Raspberry https://copperhilltech.com/pican-m-nmea-0183-nmea-2000-hat-for-raspberry-pi/

<p align="center">
<img width="500" alt="image" src="https://github.com/user-attachments/assets/cb3574d2-6b94-4899-9415-9115c67e0be5" />
</p>

- Pi + Hat Case: https://copperhilltech.com/pican-m-nmea-0183-nmea-2000-hat-for-raspberry-pi-with-smps/

<p align="center">
<img width="500" height="500" alt="image" src="https://github.com/user-attachments/assets/7ca90574-f948-4629-9897-b083aa961b6a" />
</p>

## Cable Management
  
It is also important to have the proper cable for connection to the NMEA 2000 Network backbone. The Hat connects to this using a NMEA 2000 CAN-Bus cable. There is no need to use a USB-C power cable for the Raspberry Pi, as NMEA cables have dedicated one of the prongs to supply power to any attached unit.

<p align="center">
<img width="500" alt="image" src="https://github.com/user-attachments/assets/11078809-ca95-456a-9683-19db843fce35" />
</p>

The purpose of each prong is shown in the below image:

<p align="center">
<img width="500" alt="image" src="https://github.com/user-attachments/assets/1894c956-07bd-43c7-b07e-782f17a705ca" />
</p>

# **Raspberry Pi Configuration**
The actual documentation for installation is found at the below link:

https://copperhilltech.com/content/pican-m_UGB_30.pdf

## Downloadable Files

Download the following files:

2023 OpenPlotter 64-bit Image: https://cloud.openmarine.net/s/mxrBi5K7zRj2gDq

Raspberry Pi Imager: https://www.raspberrypi.com/software/

## Physical Set-up

Using an adapter, insert a microSD card with at least 16 GB of storage into your computer. Open the Raspberry Pi Imager executable file in your system. Input the following options:

- Raspberry Pi Device > Raspberry PI 4
- Operating System > Use Custom > 2023-08-04-OpenPlotter-v3-Starting-stable-64bit-img > 2023-08-04-OpenPlotter-v3-Starting-stable-64bit
- SD Card > Entered microSD Storage

*Next*

*Select EDIT SETTINGS*

### General
- Set Username and Password // used for SSH access into the Raspberry Pi
- Configure wireless LAN // used to connect to the Raspberry Pi over Wi-Fi

### Services
- Enable SSH
- Use password authentication

### Options
- Eject media when finished
- Enable telemetry

*Save*

*Would you like to apply OS customisation settings? Yes*

*All existing data on [Storage Device Name] will be erased. Are you sure you want to continue? Yes*

At this point, wait for the microSD card to be flashed with the ChartPlotter image. 

## Flashing the Raspberry Pi

Now that the microSD has been been flashed with a new image, insert it into the Raspberry Pi. Then, plug the Raspberry Pi into the NMEA backbone cable. It is important that the microSD card is inserted before the Raspberry Pi receives power, as this will force the bootloader operation to begin. The Raspberry Pi will take a few minutes to complete this initial boot. 

While booting earlier, we left the hostname of the Raspberry Pi at its initial setting. Additionally, we configured wireless SSID settings. Due to these settings, we will temporarily have wireless compatibility between devices on the network and the Raspberry Pi. Run the below command in Linux:

```
ping raspberrypi.local
```

Results showing that ICMP packets are reaching the host indicate that the Raspberry Pi has booted and is ready for use.
