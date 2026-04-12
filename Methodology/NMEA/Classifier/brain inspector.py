import joblib
import os
# This script provides a comprehensive inspection of the trained HMM brain, allowing users to understand the 
# characteristics of each PGN instance. It displays the nature of each PGN (linear, circular, counter, static), 
# the maximum allowed delta for anomaly detection, and the means and variances of the HMM states in a 
# human-readable format. This tool is essential for validating the training process and gaining insights into the 
# behavior of different PGNs.
def inspect_brain(model_path='ML models/system_hmm_brain.pkl'):
    if not os.path.exists(model_path):
        print(f"[!] Error: {model_path} not found. Run the Builder first.")
        return

    # Load the trained brain
    brain = joblib.load(model_path)
# We print a header for the inspection report, followed by a detailed listing of each PGN instance in the brain.
    print("\n" + "="*85)
    print(f"{'PGN_INST':<15} | {'NATURE':<10} | {'MAX Δ':<8} | {'HIDDEN STATES (Mean ± Var)'}")
    print("-" * 85)
# We iterate through each PGN instance in the brain, extracting its nature, max_delta, and the means and variances of its HMM states.
    # Sort by PGN for readability
    for sid in sorted(brain.keys()):
        data = brain[sid]
        nature = data.get('nature', 'N/A').upper()
        max_delta = data.get('max_delta', 0.0)
        
        # Format the Hidden States
        # We pair the means and variances we saved in the builder
        means = data.get('means_real', [])
        vars_ = data.get('vars_real', [])
        # We format the means and variances into a readable string, showing the mean and standard deviation for each state.
        state_strings = []
        for m, v in zip(means, vars_):
            # We use square root of variance (Standard Deviation) for easier reading
            std_dev = v**0.5
            state_strings.append(f"({m:.1f} ± {std_dev:.2f})")
        
        states_formatted = " | ".join(state_strings)
# Finally, we print the details of each PGN instance in a structured format, allowing users to easily compare and analyze the 
# characteristics of different PGNs in the brain.
        print(f"{sid:<15} | {nature:<10} | {max_delta:<8.2f} | {states_formatted}")

    print("-" * 85)
    print(f"Total PGNs in Brain: {len(brain)}")
    print("="*85 + "\n")

if __name__ == "__main__":
    inspect_brain()
