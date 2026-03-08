# chord_classification.py
# Step 1: Download and inspect the isolated-guitar-chords dataset

import os
from datasets import load_dataset
import numpy as np
import librosa
import matplotlib.pyplot as plt

# Download the dataset from Hugging Face
dataset = load_dataset('severyn-k/isolated-guitar-chords')

# Inspect the dataset structure
print('Dataset splits:', dataset.keys())
print('Sample item:', dataset['train'][0])

# Save a few audio files and their labels for manual inspection
os.makedirs('sample_chords', exist_ok=True)
for i, item in enumerate(dataset['train'][:5]):
    audio = item['audio']['array']
    label = item['label']
    # Save as .wav for inspection
    from scipy.io.wavfile import write
    write(f'sample_chords/{label}_{i}.wav', item['audio']['sampling_rate'], audio)
    print(f'Saved: sample_chords/{label}_{i}.wav')
    print('Label:', label)
    if i == 4:
        break

# Feature extraction parameters
N_MELS = 64
HOP_LENGTH = 512
SR = 16000  # Target sample rate for consistency

# Directory to save features
os.makedirs('features', exist_ok=True)

# Function to extract log-mel spectrogram
def extract_logmel(audio, sr, n_mels=N_MELS, hop_length=HOP_LENGTH):
    if sr != SR:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=SR)
        sr = SR
    S = librosa.feature.melspectrogram(y=audio, sr=sr, n_mels=n_mels, hop_length=hop_length)
    log_S = librosa.power_to_db(S, ref=np.max)
    return log_S

# Process and save features for a subset (for demo; expand as needed)
for i, item in enumerate(dataset['train'][:100]):
    audio = item['audio']['array']
    sr = item['audio']['sampling_rate']
    label = item['label']
    logmel = extract_logmel(audio, sr)
    # Save as numpy file
    np.save(f'features/{label}_{i}.npy', logmel)
    # Optionally, save a visualization
    if i < 5:
        plt.figure(figsize=(6, 3))
        librosa.display.specshow(logmel, sr=SR, hop_length=HOP_LENGTH, x_axis='time', y_axis='mel')
        plt.title(f'Log-Mel Spectrogram: {label}')
        plt.colorbar(format='%+2.0f dB')
        plt.tight_layout()
        plt.savefig(f'features/{label}_{i}.png')
        plt.close()
    print(f'Extracted features for {label}_{i}')
