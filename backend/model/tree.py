import pandas as pd
import joblib
import os
import numpy as np
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier
from xgboost import XGBClassifier
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.metrics import accuracy_score, classification_report
from sklearn.utils.class_weight import compute_class_weight

# Load Data after Preprocessing
X_train = pd.read_csv("C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/preprocessing/X_train.csv").values
X_test = pd.read_csv("C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/preprocessing/X_test.csv").values
y_train = pd.read_csv("C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/preprocessing/y_train.csv").values.ravel()
y_test = pd.read_csv("C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/preprocessing/y_test.csv").values.ravel()

# Compute Class Weights (Handle class imbalance)
classes = np.unique(y_train)
class_weights = compute_class_weight(class_weight="balanced", classes=classes, y=y_train)
class_weight_dict = dict(zip(classes, class_weights))

# Feature Selection (Keep the Top 10 Most Important Features)
selector = SelectKBest(score_func=f_classif, k=10)
X_train_selected = selector.fit_transform(X_train, y_train)
X_test_selected = selector.transform(X_test)

### 📌 Train Random Forest Model
rf_model = RandomForestClassifier(
    n_estimators=200,    # More trees for better learning
    max_depth=20,        # Prevent overfitting
    min_samples_split=10,
    min_samples_leaf=5,
    class_weight="balanced",
    random_state=42
)

print("\nTraining Random Forest...")
rf_model.fit(X_train_selected, y_train)

# Evaluate Random Forest
y_pred_rf = rf_model.predict(X_test_selected)
rf_accuracy = accuracy_score(y_test, y_pred_rf)
print(f"\nRandom Forest Accuracy: {rf_accuracy:.4f}")
print("\nClassification Report (Random Forest):")
print(classification_report(y_test, y_pred_rf, zero_division=1))

# Save the Random Forest Model
output_dir = "C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/model"
os.makedirs(output_dir, exist_ok=True)
joblib.dump(rf_model, f"{output_dir}/tree_model.pkl")
print("\n✅ Random Forest model saved successfully!")

### 📌 Train XGBoost Model
xgb_model = XGBClassifier(
    n_estimators=300,  
    max_depth=10,      
    learning_rate=0.1, 
    subsample=0.8,     
    colsample_bytree=0.8,  
    random_state=42
)

print("\nTraining XGBoost...")
xgb_model.fit(X_train_selected, y_train)

# Evaluate XGBoost
y_pred_xgb = xgb_model.predict(X_test_selected)
xgb_accuracy = accuracy_score(y_test, y_pred_xgb)
print(f"\nXGBoost Accuracy: {xgb_accuracy:.4f}")
print("\nClassification Report (XGBoost):")
print(classification_report(y_test, y_pred_xgb, zero_division=1))

# Save the XGBoost Model
joblib.dump(xgb_model, f"{output_dir}/xgboost_model.pkl")
print("\n✅ XGBoost model saved successfully!")

# Compare and Print the Best Model
best_model = "Random Forest" if rf_accuracy > xgb_accuracy else "XGBoost"
print(f"\n🏆 Best Model: {best_model} with Accuracy: {max(rf_accuracy, xgb_accuracy):.4f}")
