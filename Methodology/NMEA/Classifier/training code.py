# there is BIC and AIC
# both decide on how many hidden states the pgns will have
# AIC prioritizes how accurate its predictions are. but this can lead to over fitting because 
# it might make a ton of hidden states which the model thinks is normal
# BIC is more narrow and it penalizes super complex states

# then im doing gaussian because this is a type of model that determines what the data looks like
# guassian assumes that for certain states like wind, it will cluster around some sort of mean value with a bell curve
# small, large, small bell curve

# and if it's not within this mean cluster and is std deviations away from the mean, it calculates that its bad




# Robust HMM Training Code for the Brain
# This builder processes "GoodData" files to create a robust brain model that can be used for anomaly detection.
# It incorporates nature-aware delta calculations, variance flooring, and BIC-based model selection to ensure
import os # For file handling
import re # For regex parsing
import hashlib # For file fingerprinting (deduplication)
import joblib # For saving/loading the brain model
import numpy as np # For numerical operations
from hmmlearn import hmm # For Hidden Markov Models
from sklearn.preprocessing import StandardScaler # For feature scaling
import warnings # To suppress warnings during training

# Suppress warnings for cleaner output
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=RuntimeWarning)

BRAIN_PATH = 'ML models/system_hmm_brain.pkl'
MANIFEST_PATH = 'ML models/processed_files.pkl'  # tracks which files have already been trained on

# asking what file to use for training and then building the brain model based on that data. 
# The builder will analyze the data, determine the nature of each PGN, and train a robust HMM accordingly. 
# The resulting brain is saved as a pickle file for later use in detection and inspection.
class BoatBrainBuilder:
    def __init__(self, data_folder='GoodData'):
        self.data_folder = data_folder
        self.brain = {}
        self.processed_files = {}  # filename -> md5 hash of files already trained on

    def _file_hash(self, path):
        """MD5 fingerprint of a file so we can detect if it's truly new or already seen."""
        h = hashlib.md5()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(65536), b''):
                h.update(chunk)
        return h.hexdigest()

# for each PGN instance, we will store: nature (linear, circular, counter, static), max_delta (physical limit), 
# means and variances of the HMM states, and the trained HMM model itself.
# circular nature is determined by checking if values wrap around (e.g., 350 to 10 degrees), 
# counter nature is identified by mostly positive deltas, and static nature is inferred from low variance and few unique values.
    def _get_circular_diff(self, a, b):
        diff = abs(a - b)
        return min(diff, 360 - diff)

# linear nature is the default assumption, but we check for circular and counter patterns to better model the data.
# linear is assumed if there is a mix of positive and negative deltas without wrapping, while counter is identified if the 
# vast majority of deltas are positive and values increase over time.
    def _infer_nature(self, values):
        vals = np.array(values)
        if len(vals) < 2: return "linear"
        unique_vals = np.unique(vals)
        deltas = np.diff(vals)

        if np.std(vals) < 0.0001 or len(unique_vals) <= 2:
            return "static"
        if np.min(vals) >= 0 and np.max(vals) <= 360:
            if np.any(np.abs(deltas) > 300):
                return "circular"
        positive_moves = np.sum(deltas >= 0) / len(deltas)
        if positive_moves > 0.98 and np.max(vals) > np.min(vals):
            return "counter"
        return "linear"

    def parse_line(self, line):
        try:
            parts = line.strip().split()
            if len(parts) < 5: return None
            pgn = parts[4]
            payload = line.split(":", 1)[1]
            inst_match = re.search(r"Instance\s*=\s*([^;,\n]+)", payload)
            instance = inst_match.group(1).strip().split()[-1] if inst_match else "0"
            sid = f"{pgn}_{instance}"
            matches = re.findall(r"=\s*([-+]?\d*\.\d+|\d+)", payload)
            if not matches: return None
            val = float(matches[1] if len(matches) > 1 and "2026" in matches[0] else matches[0])
            if val == 2026.0 and pgn not in ["126992", "129033"]:
                return None
            return sid, val
        except: return None

    def _train_model_for_sequence(self, values, nature):
        """
        Train a new HMM for a sequence of values.
        Returns (best_model, scaler, max_jump) or None if training fails.
        """
        unique_count = len(np.unique(values))

        # Nature-Aware Delta Calculation
        if nature == "circular":
            clean_deltas = [self._get_circular_diff(values[i], values[i-1]) for i in range(1, len(values))]
        elif nature == "counter":
            clean_deltas = [max(0, values[i] - values[i-1]) for i in range(1, len(values))]
        elif nature == "static":
            clean_deltas = [0.0]
        else:
            clean_deltas = np.abs(np.diff(values)).tolist()

        max_jump = np.percentile(clean_deltas, 99) * 2.5 if len(clean_deltas) > 0 else 5.0
        if nature == "static": max_jump = 0.01

        X_raw = np.array(values).reshape(-1, 1)
        X_jittered = X_raw + np.random.normal(0, 1e-4, X_raw.shape)
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X_jittered)

        best_bic = np.inf
        best_model = None
        max_states = min(5, unique_count)
        n_states_to_test = [1] if nature == "static" else range(1, max_states + 1)

        for n in n_states_to_test:
            try:
                model = hmm.GaussianHMM(n_components=n, covariance_type="diag", n_iter=100)
                model.fit(X_scaled)
                log_likelihood = model.score(X_scaled)
                n_features = X_scaled.shape[1]
                n_params = n**2 + 2*n*n_features - 1
                bic = -2 * log_likelihood + n_params * np.log(X_scaled.shape[0])
                if bic < best_bic:
                    best_bic = bic
                    best_model = model
            except: continue

        if best_model is None:
            return None

        return best_model, scaler, max_jump

    def _merge_into_brain(self, sid, new_values, nature, new_model, new_scaler, new_max_jump):
        """
        Merge a newly trained model for `sid` into the existing brain entry.
        
        Strategy (like a neural net weight update):
          - max_delta: take the larger of old vs new so we don't become too strict
          - means/vars: weighted average by observation count (old_weight vs new_weight)
          - model: replaced with new model trained on the COMBINED data (old representative 
            samples reconstructed from stored means + new raw values). This keeps the HMM
            fresh without forgetting what came before.
          - last_val: always update to the newest reading
        """
        if sid not in self.brain:
            # Brand new PGN — just store directly
            means_real = new_scaler.inverse_transform(new_model.means_).flatten().tolist()
            raw_vars = np.abs(new_model.covars_.flatten()) * (new_scaler.scale_**2)
            min_var = (new_max_jump * 0.05) ** 2
            vars_real = np.maximum(raw_vars, min_var).tolist()
            self.brain[sid] = {
                'model': new_model,
                'scaler': new_scaler,
                'nature': nature,
                'max_delta': new_max_jump,
                'last_val': new_values[-1],
                'means_real': means_real,
                'vars_real': vars_real,
                'observation_count': len(new_values)  # track how much data we've learned from
            }
            return

        old = self.brain[sid]
        old_count = old.get('observation_count', 100)  # assume 100 obs if not tracked (legacy entries)
        new_count = len(new_values)
        total_count = old_count + new_count

        # --- max_delta: keep the larger threshold so we don't get over-strict ---
        merged_max_jump = max(old['max_delta'], new_max_jump)

        # --- Reconstruct a synthetic "memory" of old data from stored state means ---
        # We sample proportionally from old state means so the new model retains old knowledge.
        # This is the key trick: we don't need to store raw old data. 
        # We regenerate representative points from the stored Gaussian parameters.
        old_means = np.array(old['means_real'])
        old_vars = np.array(old['vars_real'])
        
        # Generate old_count synthetic samples spread across old states
        samples_per_state = max(10, old_count // len(old_means))
        synthetic_old = []
        for mean, var in zip(old_means, old_vars):
            std = np.sqrt(var)
            synthetic_old.extend(np.random.normal(mean, std, samples_per_state).tolist())
        
        # Combine synthetic old memory with new real values
        combined_values = synthetic_old + new_values

        # Re-train a fresh model on combined data
        result = self._train_model_for_sequence(combined_values, nature)
        if result is None:
            # If combined training fails, keep old brain and just nudge max_delta
            self.brain[sid]['max_delta'] = merged_max_jump
            self.brain[sid]['last_val'] = new_values[-1]
            return

        merged_model, merged_scaler, _ = result  # use our manually computed merged_max_jump

        # Extract real-scale means/vars from the merged model
        means_real = merged_scaler.inverse_transform(merged_model.means_).flatten().tolist()
        raw_vars = np.abs(merged_model.covars_.flatten()) * (merged_scaler.scale_**2)
        min_var = (merged_max_jump * 0.05) ** 2
        vars_real = np.maximum(raw_vars, min_var).tolist()

        self.brain[sid] = {
            'model': merged_model,
            'scaler': merged_scaler,
            'nature': nature,
            'max_delta': merged_max_jump,
            'last_val': new_values[-1],
            'means_real': means_real,
            'vars_real': vars_real,
            'observation_count': total_count
        }

    def build(self):
        # ------------------------------------------------------------------ #
        # Step 0: Load existing brain and processed-file manifest if they     #
        # exist so we can build ON TOP of them rather than starting fresh.    #
        # ------------------------------------------------------------------ #
        if os.path.exists(BRAIN_PATH):
            print(f"[*] Loading existing brain from {BRAIN_PATH} ...")
            self.brain = joblib.load(BRAIN_PATH)
            print(f"    -> {len(self.brain)} PGN entries already in brain.")
        else:
            print("[*] No existing brain found. Starting fresh.")

        if os.path.exists(MANIFEST_PATH):
            self.processed_files = joblib.load(MANIFEST_PATH)
            print(f"[*] Manifest loaded: {len(self.processed_files)} previously processed files.")
        else:
            self.processed_files = {}

        if not os.path.exists(self.data_folder):
            print(f"[!] Folder {self.data_folder} not found.")
            return

        all_files = [f for f in os.listdir(self.data_folder) if f.endswith('.txt')]

        # ------------------------------------------------------------------ #
        # Step 1: Filter out files we've already trained on (same hash).      #
        # This handles the case where GoodData still contains old files.      #
        # ------------------------------------------------------------------ #
        new_files = []
        for filename in all_files:
            path = os.path.join(self.data_folder, filename)
            file_hash = self._file_hash(path)
            if self.processed_files.get(filename) == file_hash:
                print(f"  [=] Skipping (already trained): {filename}")
            else:
                new_files.append((filename, path, file_hash))

        if not new_files:
            print("\n[!] No new files to train on. Brain is already up to date.")
            return

        print(f"\n[*] Step 1: Profiling {len(new_files)} NEW file(s)...")

        # ------------------------------------------------------------------ #
        # Step 2: Parse new files into raw sequences.                         #
        # ------------------------------------------------------------------ #
        raw_sequences = {}
        for filename, path, file_hash in new_files:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    res = self.parse_line(line)
                    if res:
                        sid, val = res
                        if sid not in raw_sequences:
                            raw_sequences[sid] = []
                        raw_sequences[sid].append(val)
            # Mark file as processed
            self.processed_files[filename] = file_hash

        # ------------------------------------------------------------------ #
        # Step 3: Train new models and MERGE them into the existing brain.    #
        # ------------------------------------------------------------------ #
        print("[*] Step 2: Training & merging into brain...")
        for sid, values in raw_sequences.items():
            if len(values) < 25:
                continue

            nature = self._infer_nature(values)

            result = self._train_model_for_sequence(values, nature)
            if result is None:
                continue

            new_model, new_scaler, new_max_jump = result

            was_existing = sid in self.brain
            self._merge_into_brain(sid, values, nature, new_model, new_scaler, new_max_jump)

            entry = self.brain[sid]
            tag = "UPDATE" if was_existing else "NEW   "
            print(f"  [{tag}] {sid:15} | States: {entry['model'].n_components} | "
                  f"Nature: {entry['nature']:8} | MaxΔ: {entry['max_delta']:.2f} | "
                  f"Total obs: {entry.get('observation_count', '?')}")

        # ------------------------------------------------------------------ #
        # Step 4: Save updated brain and manifest.                            #
        # ------------------------------------------------------------------ #
        if not os.path.exists('ML models'):
            os.makedirs('ML models')

        joblib.dump(self.brain, BRAIN_PATH)
        joblib.dump(self.processed_files, MANIFEST_PATH)

        print(f"\n[!] Success: Brain updated and saved ({len(self.brain)} total PGN entries).")
        print(f"[!] Manifest saved: {len(self.processed_files)} files now on record.")


if __name__ == "__main__":
    builder = BoatBrainBuilder()
    builder.build()
