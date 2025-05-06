# SVM model
import pandas as pd
import os
import joblib
from sklearn.svm import SVC
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.preprocessing import StandardScaler
from imblearn.over_sampling import SMOTE

# Load raw data (replace with your actual dataset path)
fileCSV = "C:/xamppp/htdocs/baby_cries_classification/backend/features/extracted_features.csv"
if not os.path.exists(fileCSV):
    raise FileNotFoundError(f"The file {fileCSV} does not exist.")
df = pd.read_csv(fileCSV)

# Split data into features and labels
X = df.iloc[:, :-1].values  # Features
y = df.iloc[:, -1].values   # Labels

# Clean target labels
y = pd.Series(y).str.strip().str.lower().values
print("Unique classes in the dataset:", pd.Series(y).unique())

# Apply SMOTE to balance the dataset
smote = SMOTE(random_state=42)
X_resampled, y_resampled = smote.fit_resample(X, y)
print("Unique classes after SMOTE:", pd.Series(y_resampled).unique())

# Scale features
scaler = StandardScaler()
X_resampled = scaler.fit_transform(X_resampled)

# Split data into train and test sets
X_train, X_test, y_train, y_test = train_test_split(X_resampled, y_resampled, test_size=0.2, random_state=42)

# Hyperparameter tuning with Grid Search
param_grid = {
    'C': [1, 10],
    'gamma': ['scale',0.1],
    'kernel': ['linear', 'rbf']
}
grid_search = GridSearchCV(SVC(probability=True, class_weight='balanced', random_state=42), param_grid, cv=5)
print("Tuning hyperparameters...")
grid_search.fit(X_train, y_train)

# Best parameters
print(f"Best parameters: {grid_search.best_params_}")
svmModel = grid_search.best_estimator_

# Cross-validation accuracy
scores = cross_val_score(svmModel, X_resampled, y_resampled, cv=5, scoring='accuracy')
print(f"Cross-validation accuracy: {scores.mean():.4f}")

# Train the model
print("Training SVM...")
svmModel.fit(X_train, y_train)

# Evaluate training accuracy
y_train_pred = svmModel.predict(X_train)
train_accuracy = accuracy_score(y_train, y_train_pred)
print(f"Training accuracy: {train_accuracy:.4f}")

# Evaluate test accuracy
y_test_pred = svmModel.predict(X_test)
test_accuracy = accuracy_score(y_test, y_test_pred)
print(f"Test accuracy: {test_accuracy:.4f}")
'''
# Compare training and test accuracy
if train_accuracy > test_accuracy:
    print("The model might be overfitting.")
elif train_accuracy < test_accuracy:
    print("The model might be underfitting.")
else:
    print("The model is performing consistently on both training and test sets.")
'''
# Evaluation
y_pred = svmModel.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"SVM accuracy: {accuracy:.4f}")

# Classification report
target_names = ["belly_pain", "burping", "discomfort", "hungry", "tired"]
print("Classification report:")
print(classification_report(y_test, y_pred, target_names=target_names, zero_division=1))

# Confusion matrix
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))
# Save the Trained Model
output_dir = "C:/xamppp/htdocs/baby_cries_classification/backend/model"
os.makedirs(output_dir, exist_ok=True)
joblib.dump(svmModel, f"{output_dir}/svm_model.pkl")
print("SVM Model saved successfully")