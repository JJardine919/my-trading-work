#!/usr/bin/env python3
"""
Train BTCUSD Random Forest model with Cluster Centroids resampling
"""
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from imblearn.under_sampling import ClusterCentroids
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
import os

# Configuration
symbol = "BTCUSD"
timeframe = "PERIOD_D1"
lookahead = 1
technique_name = "cluster-centroids"

# Path to Common/Files
common_path = "Common/Files"

print(f"Training {symbol} model with {technique_name} resampling...")
print("=" * 60)

# Load data
data_file = os.path.join(common_path, f"{symbol}.{timeframe}.data.csv")
df = pd.read_csv(data_file)

print(f"Loaded {len(df)} rows from {data_file}")

# Create target variable (price goes up = 1, down = 0)
df["future_close"] = df["Close"].shift(-lookahead)
df.dropna(inplace=True)
df["Signal"] = (df["future_close"] > df["Close"]).astype(int)

print(f"Signal distribution: {np.unique(df['Signal'], return_counts=True)}")

# Prepare features and target
X = df[["Open", "High", "Low", "Close"]]
y = df["Signal"]

# Split data (70/30 train/test, no shuffle to preserve time series)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42, shuffle=False
)

print(f"\nBefore resampling: {np.unique(y_train, return_counts=True)}")

# Apply Cluster Centroids resampling
cc = ClusterCentroids(random_state=42)
X_resampled, y_resampled = cc.fit_resample(X_train, y_train)

print(f"After resampling:  {np.unique(y_resampled, return_counts=True)}")

# Train Random Forest
print("\nTraining Random Forest Classifier...")
model = RandomForestClassifier(
    n_estimators=100,
    max_depth=5,
    min_samples_split=3,
    random_state=42
)

model.fit(X_resampled, y_resampled)

# Evaluate on training set
y_train_pred = model.predict(X_train)
print("\nTrain Classification Report:")
print(classification_report(y_train, y_train_pred))

# Evaluate on test set
y_test_pred = model.predict(X_test)
print("Test Classification Report:")
print(classification_report(y_test, y_test_pred))

# Save model to ONNX
print("\nSaving model to ONNX format...")
n_features = X_train.shape[1]
initial_type = [("input", FloatTensorType([None, n_features]))]

onnx_model = convert_sklearn(model, initial_types=initial_type, target_opset=14)

output_file = os.path.join(common_path, f"{symbol}.{timeframe}.{technique_name}.onnx")
with open(output_file, "wb") as f:
    f.write(onnx_model.SerializeToString())

print(f"Model saved to: {output_file}")
print("\n" + "=" * 60)
print("Training complete!")
print(f"To use this model, set: symbol='BTCUSD', technique_name='{technique_name}'")
