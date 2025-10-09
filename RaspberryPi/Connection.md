# SSH and Package Installation
## SSH Connection
Assuming the Raspberry Pi has connectivitiy with your device, ssh into it:
```
ssh username@raspberrypi.local
```
Enter the username and password you set up during configuration.

## Configuration Changes
In terminal, run the following sequence of commands:
```
sudo apt-get update
sudo apt-get upgrade
sudo reboot
```
After restart, continue:
```
sudo nano /boot/config.txt

enable_uart=1
dtparam=i2c_arm=on
dtparam=spi=on
dtoverlay=mcp2515=can0,oscillator=16000000,interrupt=25

CTRL-X to Save and Exit
```
Because we installed the ChartPlotter image on the Raspberry Pi, many of the tools necessary for analysis are already installed. The vast majority of NMEA 2000 analysis can be completed with the can-utils package. It includes tools such as candump, canplayer, and analyzer/candump2analyzer.

# GUI
info here
