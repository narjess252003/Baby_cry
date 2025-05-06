import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, Flatten, Reshape
import numpy as np
import os
import cv2
data_directory = "C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/spectrograms/"
classes = [d for d in os.listdir(data_directory) if os.path.isdir(os.path.join(data_directory, d))]
img_size = 128  #should all have same sizee 
#loading dataset
def load_data():
    X, y = [], []
    for idx, label in enumerate(classes):
        class_path = os.path.join(data_directory, label)
        for img_name in os.listdir(class_path):
            img_path = os.path.join(class_path, img_name)
            img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)  #read image in grayscale
            img = cv2.resize(img, (img_size, img_size))  #set image 128x128 
            X.append(img)
            y.append(idx)
    return np.array(X) / 255.0, np.array(y)  #normalize pixel values
X, y = load_data()
#reshape from [samples,height,width,1] to [samples, timesteps, features])
X = X.reshape(X.shape[0], img_size, img_size)  #timesteps=img_size and aslo features=img_size

# Split data into training and testing sets
from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# LSTM Model
model = Sequential([
    Reshape((X_train.shape[1], X_train.shape[2]), input_shape=(X_train.shape[1], X_train.shape[2])),  # Reshape to (timesteps, features)
    LSTM(128, activation='relu', return_sequences=False),  # LSTM layer
    Dropout(0.2),  # Dropout layer to reduce overfitting
    Dense(64, activation='relu'),  # Dense layer
    Dense(len(classes), activation='softmax')  # Output layer with softmax for multi-class classification
])

# Compile Model
model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

# Train Model
print("Start Training LSTM Model...")
history = model.fit(X_train, y_train, epochs=20, batch_size=32, validation_data=(X_test, y_test))

# Evaluate Model
test_loss, test_acc = model.evaluate(X_test, y_test)
print(f"LSTM Accuracy: {test_acc:.4f}")

# Save Model
model.save("C:/Users/INFOKOM/Desktop/stage_pfe/baby_cries_classification/model/lstm_model.h5")
print("LSTM Model saved as lstm_model.h5")
