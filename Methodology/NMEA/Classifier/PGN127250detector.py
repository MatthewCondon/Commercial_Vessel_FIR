# This code implements a Heading Verifier that uses a pre-trained HMM brain to analyze NMEA log files for anomalies in vessel 
# heading data. It combines HMM-based state analysis with physics-based checks to identify potential anomalies, and 
# generates a graph of the heading data with anomalies highlighted.

import os
import joblib
import numpy as np
import re
import warnings
import matplotlib.pyplot as plt

warnings.filterwarnings("ignore")

# --- CONFIGURATION ---
MODEL_PATH = os.path.join('ML models', 'system_hmm_brain.pkl')
BADDATA_DIR = 'Baddata' 
TARGET_PGN = "127250" # Vessel Heading
# The HeadingVerifier class loads the trained HMM brain, parses heading data from selected NMEA log files, and applies both
class HeadingVerifier:
    def __init__(self, brain_path):
        self.brain_path = brain_path
        self.brain = None
        self.last_val = None
        self.last_line = "N/A"
        
        # Data for Graphing
        self.plot_x = [] # Line numbers
        self.plot_y = [] # Heading values
        self.anomaly_x = []
        self.anomaly_y = []
        self.anomalies_found = 0
# HMM-based and physics-based checks to identify anomalies in the heading data. It also generates a graph of the heading data 
# with anomalies highlighted.
    def load_brain(self):
        if not os.path.exists(self.brain_path):
            print(f"[!] Brain not found at {self.brain_path}. Run trainer first.")
            return False
        full_brain = joblib.load(self.brain_path)
        self.brain = {k: v for k, v in full_brain.items() if k.startswith(TARGET_PGN)}
        return True if self.brain else False
# The parse_heading method extracts the heading value from a log line, ensuring that it belongs to the target PGN 
# and is properly formatted.
    def parse_heading(self, line):
        try:
            if TARGET_PGN not in line: return None
            payload = line.split(":", 1)[1]
            inst_match = re.search(r"Instance\s*=\s*([^;,\n]+)", payload)
            instance = inst_match.group(1).strip().split()[-1] if inst_match else "0"
            sid = f"{TARGET_PGN}_{instance}"
            val_match = re.search(r"Heading\s*=\s*([-+]?\d*\.\d+|\d+)", payload)
            if val_match:
                return sid, float(val_match.group(1))
            return None
        except: return None
# The get_circular_diff method calculates the circular difference between two heading values, accounting for wrap-around at 360 degrees.
    def get_circular_diff(self, a, b):
        diff = abs(a - b)
        return min(diff, 360 - diff)
# The verify method loads the brain, allows the user to select a log file, and processes each line to detect anomalies 
# based on HMM state probabilities and physics-based checks. It also collects data for graphing and prints a report of 
# detected anomalies.
    def verify(self):
        if not self.load_brain(): return
        
        files = [f for f in os.listdir(BADDATA_DIR) if f.endswith('.txt')]
        print("\n--- HEADING ANALYZER + GRAPHING ---")
        for idx, filename in enumerate(files): print(f"[{idx}] {filename}")
        # We prompt the user to select a log file for analysis, and then we process each line of the selected file to 
        # extract heading data and detect anomalies.
        try:
            choice = int(input("\nSelect index: "))
            target_path = os.path.join(BADDATA_DIR, files[choice])
            file_name = files[choice]
        except: return

        print(f"\n{'Line':<8} | {'Heading':<7} | {'Delta':<7} | {'Certainty'} | {'Reason'}")
        print("-" * 80)
# We read the selected log file line by line, extracting heading values and applying both HMM-based and physics-based 
# checks to identify anomalies.
        with open(target_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f):
                res = self.parse_heading(line)
                if not res: continue
                
                sid, val = res
                if sid in self.brain:
                    meta = self.brain[sid]
                    max_allowed = meta['max_delta']
                    
                    # Log data for the main graph line
                    self.plot_x.append(line_num)
                    self.plot_y.append(val)

                    if self.last_val is None:
                        self.last_val = val
                        self.last_line = line.strip()
                        continue
                    
                    delta = self.get_circular_diff(val, self.last_val)
                    
                    # 1. HMM Probability Check
                    try:
                        obs_scaled = meta['scaler'].transform([[val]])
                        score = meta['model'].score(obs_scaled)
                        hmm_certainty = min(100.0, abs(score) / 2.0) if score < -20 else 0.0
                    except: hmm_certainty = 0.0

                    # 2. Physics Certainty Check
                    physics_certainty = 0.0
                    if delta > max_allowed:
                        severity = delta / max_allowed
                        physics_certainty = min(100.0, 70.0 + (severity * 10))

                    total_certainty = max(hmm_certainty, physics_certainty)
# If the total certainty exceeds 80%, we consider it an anomaly and log it with the reason (either physics or HMM violation).
                    if total_certainty > 80.0:
                        self.anomalies_found += 1
                        self.anomaly_x.append(line_num)
                        self.anomaly_y.append(val)
                        
                        reason = "PHYSICS" if physics_certainty > hmm_certainty else "HMM STATE"
                        print(f"{line_num:<8} | {val:<7.1f} | {delta:<7.1f} | {total_certainty:>8.1f}% | {reason} VIOLATION")
                    
                    self.last_val = val
                    self.last_line = line.strip()

        print(f"\nFound {self.anomalies_found} Anomalies. Generating graph...")
        self.show_graph(file_name)

    def show_graph(self, title):
        plt.figure(figsize=(12, 6))
        
        # Plot the normal data flow
        plt.plot(self.plot_x, self.plot_y, label='Heading Data', color='blue', alpha=0.6, linewidth=1)
        
        # Plot the anomalies as red dots
        if self.anomaly_x:
            plt.scatter(self.anomaly_x, self.anomaly_y, color='red', label='Anomalies Detected', zorder=5, marker='x', s=100)
            
            # Add labels for specific line numbers to the graph
            for i, txt in enumerate(self.anomaly_x):
                if i % 5 == 0: # Only label every 5th anomaly to avoid clutter
                    plt.annotate(f"Line {txt}", (self.anomaly_x[i], self.anomaly_y[i]), 
                                 textcoords="offset points", xytext=(0,10), ha='center', fontsize=8, color='red')

        plt.title(f"Heading Anomaly Detection: {title}")
        plt.xlabel("NMEA Log Line Number")
        plt.ylabel("Heading (Degrees 0-360)")
        plt.ylim(-10, 370)
        plt.legend()
        plt.grid(True, linestyle='--', alpha=0.7)
        plt.show()

if __name__ == "__main__":
    HeadingVerifier(MODEL_PATH).verify()
