import os
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from datasets import load_dataset
import librosa
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import json

# ==========================================
# 1. Configuration & Parameters
# ==========================================
N_MELS = 64
HOP_LENGTH = 512
SR = 16000
TARGET_LENGTH = 128  # Fixed number of frames for input (approx 4 seconds at SR=16000, HOP_LENGTH=512)

# ==========================================
# 2. Data Loading & Feature Extraction Pipeline
# ==========================================
print("Loading dataset 'severyn-k/isolated-guitar-chords'...")
dataset = load_dataset('severyn-k/isolated-guitar-chords')

labels = []
features = []

print("Extracting Mel Spectrograms...")
# Pre-allocate feature list for quicker processing
for i, item in enumerate(dataset['train']):
    audio = item['audio']['array']
    sr = item['audio']['sampling_rate']
    label = item['label']
    
    # Resample if needed
    if sr != SR:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=SR)
        sr = SR
        
    # Extract Log-Mel Spectrogram
    S = librosa.feature.melspectrogram(y=audio, sr=sr, n_mels=N_MELS, hop_length=HOP_LENGTH)
    log_S = librosa.power_to_db(S, ref=np.max)
    
    # Pad or truncate to TARGET_LENGTH frames
    if log_S.shape[1] < TARGET_LENGTH:
        pad_width = TARGET_LENGTH - log_S.shape[1]
        log_S = np.pad(log_S, ((0, 0), (0, pad_width)), mode='constant', constant_values=-80.0)
    else:
        log_S = log_S[:, :TARGET_LENGTH]
        
    features.append(log_S)
    labels.append(label)
    
    if (i + 1) % 100 == 0:
        print(f"Processed {i + 1} samples...")

X = np.array(features)
# Reshape for CNN input: [samples, height, width, channels]
X = X.reshape(X.shape[0], N_MELS, TARGET_LENGTH, 1)

# Encode Labels
label_encoder = LabelEncoder()
y = label_encoder.fit_transform(labels)
num_classes = len(label_encoder.classes_)

# Save label mapping for Flutter
os.makedirs('model_output', exist_ok=True)
with open('model_output/labels.txt', 'w') as f:
    for cls in label_encoder.classes_:
        f.write(f"{cls}\n")
print(f"Found {num_classes} unique chords. Labels saved to model_output/labels.txt")

# Split Data
X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42)

# ==========================================
# 3. Model Architecture (Lightweight CNN)
# ==========================================
print("Building CNN Model...")
model = models.Sequential([
    layers.InputLayer(input_shape=(N_MELS, TARGET_LENGTH, 1)),
    layers.Conv2D(16, (3, 3), activation='relu', padding='same'),
    layers.MaxPooling2D((2, 2)),
    layers.Conv2D(32, (3, 3), activation='relu', padding='same'),
    layers.MaxPooling2D((2, 2)),
    layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
    layers.GlobalAveragePooling2D(),
    layers.Dense(64, activation='relu'),
    layers.Dense(num_classes, activation='softmax')
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])

model.summary()

# ==========================================
# 4. Training
# ==========================================
print("Training Model...")
early_stopping = tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)

history = model.fit(
    X_train, y_train,
    epochs=50,
    batch_size=32,
    validation_data=(X_val, y_val),
    callbacks=[early_stopping]
)

# ==========================================
# 5. Conversion to TFLite (with Quantization)
# ==========================================
print("Converting to TensorFlow Lite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT] # Post-training quantization

tflite_model = converter.convert()

with open('model_output/chord_classifier.tflite', 'wb') as f:
    f.write(tflite_model)

print("✅ Model training and conversion complete!")
print("Artifacts saved to 'model_output/' directory:")
print(" - chord_classifier.tflite")
print(" - labels.txt")
