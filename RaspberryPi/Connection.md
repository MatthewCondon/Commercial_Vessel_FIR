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
```
CTRL-X to Save and Exit

Because we installed the ChartPlotter image on the Raspberry Pi, many of the tools necessary for analysis are easily installed and not traditionally available on normal Linux systems. The vast majority of NMEA 2000 analysis can be completed with the can-utils package. It includes tools such as candump, canplayer, and analyzer/candump2analyzer.
```
sudo apt-get install can-utils
```

# GUI
For enhanced FIR capabilities, we need to use a GUI provided by ChartPlotter. It will allow us to have another method off reviewing vessel data.

First, ssh into the Raspberry Pi:
```
ssh ubuntu@raspberrypi.local
```
Enter the associated username and password

The program we need to use is SignalK. We need to ensure it is running:
```
sudo systemctl status signalk
```
If it is not running, we need to reconfigure the system service.
```
sudo systemctl stop signalk
sudo nano /etc/systemd/system/signalk.service
```
Remove all information currently in the signalk.service file. Replace it with the below information:
```
[Unit]
Description=Signal K Node Server
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/bin/signalk-server
Restart=always
Environment=NODE_ENV=production
WorkingDirectory=/home/ubuntu/.signalk
SyslogIdentifier=signalk

[Install]
WantedBy=multi-user.target
```
CTRL-X to Save and Exit

Restart the service:
```
sudo systemctl daemon-reload
sudo systemctl enable signalk
sudo systemctl restart signalk
```

Verify it is now running:
```
sudo systemctl status signalk
sudo netstat -tlnp | grep 3000
```
The associated output should look like:
```
ubuntu@raspberrypi:~ $ sudo systemctl status signalk
sudo netstat -tlnp | grep 3000
● signalk.service - Signal K Node Server
     Loaded: loaded (/etc/systemd/system/signalk.service; enabled; vendor preset: enabled)
     Active: active (running) since Fri 2025-10-10 15:24:30 BST; 3s ago
TriggeredBy: ● signalk.socket
   Main PID: 1071 (node)
      Tasks: 7 (limit: 8755)
        CPU: 2.316s
     CGroup: /system.slice/signalk.service
             └─1071 node /usr/bin/signalk-server

Oct 10 15:24:30 raspberrypi systemd[1]: Started Signal K Node Server.
```

Now, you should be able to navigate to the following link for the SignalK GUI:
```
http://raspberrypi.local:3000
```

The webpage should show the following information:

<img width="500" alt="image" src="https://github.com/user-attachments/assets/4a9adec1-8460-4c73-90e9-b5fb6725e5f4" />

Default credentials for the ```/admin``` page are ```admin:1234```
