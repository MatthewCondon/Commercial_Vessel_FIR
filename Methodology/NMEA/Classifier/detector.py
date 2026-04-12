import os
import joblib
import numpy as np
import re
import warnings
import matplotlib.pyplot as plt

warnings.filterwarnings("ignore")

class UniversalBoatWatchdog:
    def __init__(self, brain_path='ML models/system_hmm_brain.pkl'):
        self.brain_path = brain_path
        self.full_brain = {}
        self.last_vals = {}
        self.plot_data = {}
        self.ignored_pgns = ['129033', '126992', '129025', '129026', '129029']

    def load_brain(self):
        if not os.path.exists(self.brain_path):
            print(f"[!] Brain file not found at {self.brain_path}")
            return False
        self.full_brain = joblib.load(self.brain_path)
        return True

    def get_circular_diff(self, a, b):
        diff = abs(a - b)
        return min(diff, 360 - diff)

    def parse_line_dynamic(self, line):
        try:
            if "Unknown" in line: return None
            parts = line.strip().split()
            if len(parts) < 5: return None
            pgn = parts[4]
            if pgn in self.ignored_pgns: return None
            
            payload = line.split(":", 1)[1]
            inst_match = re.search(r"Instance\s*=\s*([^;,\n]+)", payload)
            instance = inst_match.group(1).strip().split()[-1] if inst_match else "0"
            sid = f"{pgn}_{instance}"
            
            if sid not in self.full_brain: return None

            # Robust value extraction
            matches = re.findall(r"(?<!SID)(?<!Instance)\s*=\s*([-+]?\d*\.\d+|\d+)", payload, re.IGNORECASE)
            if not matches: return None
            return sid, float(matches[-1])
        except: return None

    def monitor(self):
        if not self.load_brain(): return
        baddata_dir = 'Baddata'
        files = [f for f in os.listdir(baddata_dir) if f.endswith('.txt')]
        for idx, f in enumerate(files): print(f"[{idx}] {f}")
        
        try:
            choice = int(input("\nSelect file index: "))
            target_path = os.path.join(baddata_dir, files[choice])
            file_name = files[choice]
        except: return

        print(f"\n{'LINE':<8} | {'PGN_INST':<15} | {'VAL':<8} | {'DELTA':<7} | {'SURE%':<6} | {'REASON'}")
        print("-" * 90)

        anomalies_found = 0
        with open(target_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f):
                res = self.parse_line_dynamic(line)
                if not res: continue
                
                sid, val = res
                meta = self.full_brain[sid]
                
                if sid not in self.plot_data:
                    self.plot_data[sid] = {'x': [], 'y': [], 'ax': [], 'ay': []}
                
                self.plot_data[sid]['x'].append(line_num)
                self.plot_data[sid]['y'].append(val)

                if sid not in self.last_vals:
                    self.last_vals[sid] = val
                    continue
                
                prev_v = self.last_vals[sid]
                nature = meta.get('nature', 'gauge')
                max_allowed = meta['max_delta']
                
                # --- CALC DELTA ---
                if nature == "circular":
                    delta = self.get_circular_diff(val, prev_v)
                elif nature == "counter":
                    delta = val - prev_v
                else:
                    delta = abs(val - prev_v)

                # --- 1. PHYSICS CHECK (Primary) ---
                physics_certainty = 0.0
                if nature == "counter" and delta < -0.1:
                    physics_certainty = 98.0 # Critical Reset
                elif delta > max_allowed and delta > 0.05: # Ignore micro-jitter
                    severity = delta / (max_allowed if max_allowed > 0 else 0.1)
                    physics_certainty = min(100.0, 75.0 + (severity * 5))

                # --- 2. HMM CHECK (Secondary & Dampened) ---
                hmm_certainty = 0.0
                # ONLY run HMM if the value actually changed. 
                # This stops 0.00 -> 0.00 from being flagged.
                if delta > 0:
                    try:
                        obs_scaled = meta['scaler'].transform([[val]])
                        score = meta['model'].score(obs_scaled)
                        # Much stricter threshold for HMM to avoid false positives
                        if score < -50: 
                            hmm_certainty = min(100.0, abs(score) / 2.0)
                    except: pass

                total_certainty = max(physics_certainty, hmm_certainty)

                # Trigger threshold
                if total_certainty > 85.0:
                    anomalies_found += 1
                    self.plot_data[sid]['ax'].append(line_num)
                    self.plot_data[sid]['ay'].append(val)
                    
                    reason = "PHYSICS" if physics_certainty >= hmm_certainty else "HMM"
                    print(f"{line_num:<8} | {sid:<15} | {val:<8.2f} | {delta:<7.2f} | {total_certainty:>5.1f}% | {reason} VIOLATION")

                self.last_vals[sid] = val

        if anomalies_found > 0:
            print(f"\n[!] Detected {anomalies_found} anomalies.")
            self.show_graphs(file_name)
        else:
            print("\n[+] No anomalies detected.")

    def show_graphs(self, title):
        active_plots = [sid for sid, data in self.plot_data.items() if data['ax']]
        for sid in active_plots:
            plt.figure(figsize=(10, 4))
            data = self.plot_data[sid]
            plt.plot(data['x'], data['y'], label=f'Data: {sid}', color='blue', alpha=0.5)
            plt.scatter(data['ax'], data['ay'], color='red', marker='x', s=50, label='Anomaly')
            plt.title(f"Anomalies in {sid} ({title})")
            plt.grid(True, alpha=0.3)
            plt.legend()
            plt.show()

if __name__ == "__main__":
    UniversalBoatWatchdog().monitor()  
