# Approaches
There are two primary approaches to be employed when analyzing a vessel for a possible cyber influence. Each requires different questions to be asked during investigation. 

## Proactive
### This is focused on investigations before an incident, and centers on ensuring safety and compliance.
Investigation Areas:
- Ensure VDR is collecting data normally
- Determine if any abnormal devices are on the NMEA network
- Identify any open connectors that communicate with the NMEA backbone

Questions to Ask:
- Is the VDR fully operational and processing accurate data?
- Who has access to the VDR? NMEA backbone connections? ECDIS computers?

## Reactive
### This is focused on incident response investigations after an incident has occurred, and determining if and when a cyberattack occurred.
Investigation Areas:
- Determine if any devices were sending abnormal packets (timing, content, etc.)
- Identify unknown devices on the NMEA network (Raspberry Pi, USB, etc.)
- Check all wires and cables to ensure they are operational (water damage, loose connection, etc.)

Questions to Ask:
- Where is the VDR? Did it continue collecting after the incident occurred/was noticed?
- Is the NMEA network still operating?
- Is there any other known source of historical NMEA data? What devices besides the VDR are collecting and storing NMEA data?
