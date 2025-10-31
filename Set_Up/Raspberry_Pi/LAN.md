# Configuring the LAN
In order to take the Raspberry Pi directly onto the vessel for purposes such as monitoring or replay, the Raspberry Pi and the computer need to be on the same LAN. Not every vessel will have a network that the Raspberry Pi or investigator computers can connect to, so it is important to account for wireless and wired communications.

## Temporarily Reconfiguring IP Interfaces
It is critical to reeconfigure the ```eth0``` interface, as this is the one used for wired ethernet cable connections. Updating the ```wlan0``` interface will only allow wireless connections to static addresses if both the investigator computer and Raspberry Pi are on the same WiFi.

By reconfiguring only the ```eth0``` interface and not changing the ```wlan0```, investigators maintain wireless and wired connectivity with the Raspberry Pi. As such, communications can occur on a normal wireless network or using an ethernet cable, depending on the technical environment of the bridge and ship.

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

### Raspberry Pi
On the Raspberry Pi, run:
```
sudo ip addr add 192.168.1.2/24 dev eth0
```
To confirm the change, run:
```
ip a
```

The command result of ```ip a``` will be:

<img width="858" height="368" alt="Pi_after" src="https://github.com/user-attachments/assets/80034439-8aed-41ae-b262-785390386563" />

## Reconnecting to the Raspberry Pi
Now, investigators should be able to ssh into the Raspberry Pi normally using the new network. You will need to accept the fingerprint once more, but no other settings need to be updated:

<img width="979" height="338" alt="Only_eth" src="https://github.com/user-attachments/assets/257772b5-79e1-44fa-9759-d13c5bc2e637" />

## Permanently Reconfiguring IP Interfaces
The computer and Raspberry Pi static addresses are volatile if the computer needs to restart, so you may want to make it a permanent change.

### Investigating Compputer
On the investigating computer, run:
```
nmcli connection show
```
You should be connected physically via an ethernet cable. This should show as "Wired Connection 1" or something similar. Now, run the following commands:
```
sudo nmcli connection modify "Wired connection 1" ipv4.addresses 192.168.1.3/24 ipv4.method manual
sudo nmcli connection up "Wired connection 1"
```
Upon completion, the terminal should resturn feedback indicating a successful activation.

### Raspberry Pi
On the Raspberry Pi, run:
```
sudo nano /etc/dhcpcd.conf
```
Scroll to the bottom of the file and add the following text:
```
interface eth0
static ip_address=192.168.1.2/24
```
Finally, restart the Raspberry Pi connectivity configurations:
```
sudo systemctl restart dhcpcd
```
You can also reboot the entire Raspberry Pi.

# Connectivity
To ensure the static IP addresses have been properly assigned, ping the investigating computer from the Raspberry Pi and the Raspberry Pi from the investigating computer.
