# SSH and Package Installation
Assuming the Raspberry Pi has connectivitiy with your device, ssh into it:
```
ssh username@raspberrypi.local
```
Enter the username and password you set up during configuration.

In terminal, run the following sequence of commands:
```
sudo apt-get update
sudo apt-get upgrade
sudo reboot
```
After restart, continue:
````
sudo nano /boot/config.txt

enable_uart=1
dtparam=i2c_arm=on
dtparam=spi=on
dtoverlay=mcp2515=can0,oscillator=16000000,interrupt=25

CTRL-X to Save and Exit
```


# GUI
info here
