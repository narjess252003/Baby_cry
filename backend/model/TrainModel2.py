#random forest
import pandas as pd
import joblib
import os
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)) + "/..")  # Adjust the path to include the parent directory  
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight
from imblearn.over_sampling import SMOTE
from sklearn.model_selection import train_test_split
from features.featuresExtraction import extractMfcc, extractChroma, extractSpectral, extractZCR, loading

# Load data after Preprocessing
fileCSV = "C:/xamppp/htdocs/baby_cries_classification/backend/features/extracted_features.csv"
if not os.path.exists(fileCSV):
    raise FileNotFoundError(f"The file {fileCSV} does not exist.")
df = pd.read_csv(fileCSV)

# Split data into features and labels
X = df.iloc[:, :-1].values  # Features
y = df.iloc[:, -1].values   # Labels

# Apply SMOTE to balance the dataset
smote = SMOTE(random_state=42)
X_resampled, y_resampled = smote.fit_resample(X, y)

# Split data into train and test sets
X_train, X_test, y_train, y_test = train_test_split(X_resampled, y_resampled, test_size=0.2, random_state=42)

# Calculate class weights
classes = np.unique(y_train)  # Extract unique classes
class_weights = compute_class_weight(class_weight='balanced', classes=classes, y=y_train)
class_weights_dict = {classes[i]: class_weights[i] for i in range(len(classes))}

# Print class weights
print("Class Weights:", class_weights_dict)

# Initialize the RandomForestClassifier with class weights
rf_model = RandomForestClassifier(random_state=42, class_weight=class_weights_dict)

# Train the model
print("\nTraining Random Forest...")
rf_model.fit(X_train, y_train)

# Evaluate training accuracy
y_train_pred = rf_model.predict(X_train)
train_accuracy = accuracy_score(y_train, y_train_pred)
print(f"\nTraining Accuracy: {train_accuracy:.4f}")

# Evaluate test accuracy
y_test_pred = rf_model.predict(X_test)
test_accuracy = accuracy_score(y_test, y_test_pred)
print(f"Test Accuracy: {test_accuracy:.4f}")

# Evaluate the Model
y_pred = rf_model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"\nRandom Forest Accuracy: {accuracy:.4f}")
print("Classification Report:")
print(classification_report(y_test, y_pred, zero_division=1))

# Confusion Matrix
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

# Save the Trained Model
output_dir = "C:/xamppp/htdocs/baby_cries_classification/backend/model"
os.makedirs(output_dir, exist_ok=True)
joblib.dump(rf_model, f"{output_dir}/random_forest_model.pkl")
print("Random Forest Model saved as random_forest_model.pkl")

# Predict the first object of the test set independently
first_sample = X_test[0].reshape(1, -1)  # Reshape to match the expected input shape
first_prediction = rf_model.predict(first_sample)[0]  # Get the predicted label directly
print(f"\nFirst Sample Prediction: {first_prediction}")
print(f"Actual Label: {y_test[0]}")

# Predict the last object of the test set independently
last_sample = X_test[-1].reshape(1, -1)  # Reshape to match the expected input shape
last_prediction = rf_model.predict(last_sample)[0]  # Get the predicted label directly
print(f"\nLast Sample Prediction: {last_prediction}")
print(f"Actual Label: {y_test[-1]}")
