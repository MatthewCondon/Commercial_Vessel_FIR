# HMM Classifier
The purpose of these scripts is identifying anomalous behavior in all possible PGNs.

**The required NMEA 2000 data format is...**

in this format for these scripts, txt files of the data 

Using a Hidden Markov Model (HMM) the system learns the "normal" behavior of a vessel’s sensors—such as Rudder Position, Engine RPM, and Vessel Heading—and flags anomalies that could indicate sensor failure, data corruption, or mechanical issues.

1. The training phase (Brain Builder)
     The system analyzes "Good Data" to create a behavioral profile for every sensor (PGN).
     Nature Inference: Automatically detects if a sensor is Linear (Temperature), Circular (Compass/Heading), Counter (Engine Hours), or Static.
     BIC (Bayesian Information Criterion): Uses BIC math to determine the optimal number of hidden states for each sensor. This prevents "Overfitting," ensuring the model stays lean and ignores minor electronic noise.
     Gaussian Modeling: Each state is defined by a Gaussian Bell Curve. This allows the model to mathematically define a "Safety Zone" around normal values.

2. Detection phase
     HMM Probability: If a sensor value falls into a statistically "impossible" area of the learned Gaussian curve, the HMM flags a violation.
     Physics Overrides: The system calculates the Delta (change) between readings. If a rudder jumps $40^\circ$ in a fraction of a second, the system flags it as a physics violation, even if the value itself is within a
     "normal" range.


This was the GOAL FOR THIS PORTION

However, due to the lack of data from various sources, as well as overall lack of data, this was not able to be completed fully. Due to the limited size of the available training datasets, the HMM component is highly sensitive to "out-of-distribution" values.
This classification model is on track for ML based classification and anomaly detection using the Good Data tested with the Bad Data, however, it is left for the next group to continue this work.

To understand what was built,

1. Training code looks at all data in the "GoodData" folder to train the data
2. This puts it all into the different files such as system_hmm_brain.pkl and system_hmm_models.pkl which is just a way of compression of data to be used as a brain.
3. I also created Brain inspector to allow the user to check what is in the pkl files as we cannot read them.
4. then can use detector to try and find anomalies using a file from the bad data.
5. While this may work for the 127250 PGN, it was not massively produced, and there may be some nuances to it as it was not perfected.

From this ss, you can see how the singlePGNDetection worked for the 127250. it found two instances in data8 Bad Data of a massive spike in heading that is anomalous 
<img width="613" height="323" alt="Screenshot 2026-02-09 090348" src="https://github.com/user-attachments/assets/c4aed058-8bf9-443e-8bdb-6009613c4f22" />
