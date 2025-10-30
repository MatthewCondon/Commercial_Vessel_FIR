# Configuring the LAN
In order to take the Raspberry Pi directly onto the vessel for purposes such as monitoring or replay, the Raspberry Pi and the computer need to be on the same LAN. Not every vessel will have a network that the Raspberry Pi or investigator computers can connect to, so it is important to account for wireless and wired communications.

## Reconfiguring IP Interfaces
It is critical to reeconfigure the ```eth0``` interface, as this is the one used for wired ethernet cable connections. Updating the ```wlan0``` interface will only allow wireless connections to static addresses if both the investigator computer and Raspberry Pi are on the same WiFi.

### Investigating Computer
On the investigating computer, run:
```
sudo ip addr add 192.168.1.3/24 dev eth0
```
To confirm the change, run:
```
ip a
```

The command result of ```ip a``` will be:

<img width="808" height="299" alt="Kali_after" src="https://github.com/user-attachments/assets/02952246-3182-46bd-b7be-41759fa21742" />


### RaspberryPi
On the investigating computer, run:
```
sudo ip addr add 192.168.1.2/24 dev eth0
```
To confirm the change, run:
```
ip a
```

The command result of ```ip a``` will be:

<img width="858" height="368" alt="Pi_after" src="https://github.com/user-attachments/assets/80034439-8aed-41ae-b262-785390386563" />
