# Summary
This directory contains information on Anomaly Detection. The purpose is to identify deviations from normal patterns and detect anomalies in data values.


PGN-Specific Scripts
The purpose of these scripts is identifying anomalous behavior in specific and common PGNs.

The required NMEA 2000 data format is...

plot_dict.py:

Enables users to see what PGNs are in files and allows them to graph up to two of them. The idea being users can visually compare PGNs to find anomolies.

Graphs based off MAD deviation.

Recomended Pairings:

Navigation Consistency (High Priority) 127250 (Vessel Heading) ↔ 127245 (Rudder) → Heading should respond to rudder input → Detect: steering failure, spoofing, control mismatch 127250 (Vessel Heading) ↔ 127251 (Rate of Turn) → Heading change rate should match ROT → Detect: sensor inconsistency or injected data 127250 (Vessel Heading) ↔ 129026 (COG & SOG) → Heading ≈ Course Over Ground (except drift) → Detect: GPS spoofing, drift anomalies Position & Movement Validation 129025 (Position) ↔ 129026 (COG & SOG) → Position updates should align with speed/course → Detect: impossible jumps or spoofed movement 129029 (GNSS Data) ↔ 129025 (Position) → Raw GNSS vs processed position → Detect: GNSS manipulation 129026 (COG & SOG) ↔ 128259 (Speed) → Speed over ground vs water speed → Detect: current influence vs bad data Environmental Impact vs Vessel Behavior 130306 (Wind Data) ↔ 127250 (Heading) → Wind should influence heading/drift → Detect: unrealistic stability or false wind data 130306 (Wind Data) ↔ 129291 (Set & Drift) → Wind should correlate with drift → Detect: environmental sensor anomalies 129291 (Set & Drift) ↔ 129026 (COG & SOG) → Drift affects actual movement vs intended → Detect: current inconsistencies Stability & Motion 127252 (Heave) ↔ 128267 (Water Depth) → Depth changes + vessel motion correlation → Detect: bad sonar or motion data 127251 (Rate of Turn) ↔ 127245 (Rudder) → Turn rate should follow rudder angle → Detect: steering system issues Engineering / Machinery Cross-Checks 127488 (Engine Params Rapid) ↔ 127489 (Engine Params Dynamic) → Engine data should be consistent → Detect: sensor faults 127493 (Transmission) ↔ 128259 (Speed) → Gear + engine → vessel speed → Detect: propulsion inconsistencies 127505 (Fluid Level) ↔ 127506 (DC Status) → System state vs resource levels → Detect: reporting inconsistencies Electrical Systems 127508 (Battery Status) ↔ 127506 (DC Detailed Status) → Voltage/current consistency → Detect: electrical faults or bad telemetry Time & Data Integrity 129033 (Time & Date) ↔ All PGNs (timestamps) → Time consistency across messages → Detect: replay attacks, logging issues
