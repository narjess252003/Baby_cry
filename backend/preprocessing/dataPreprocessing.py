from sklearn.model_selection import train_test_split
import pandas as pd

def preprocess_data(fileCSV):
    # Load dataset
    df = pd.read_csv(fileCSV)
    
    # Split data into features and labels
    X = df.iloc[:, :-1].values  # Features
    y = df.iloc[:, -1].values   # Labels
    
    # Split data into train and test sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    return X_train, X_test, y_train, y_test

# Example usage
fileCSV = r"C:\Users\INFOKOM\Desktop\stage_pfe\baby_cries_classification\features\extracted_features.csv"
X_train, X_test, y_train, y_test = preprocess_data(fileCSV)