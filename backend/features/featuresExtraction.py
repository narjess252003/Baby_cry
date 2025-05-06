import librosa
import numpy as np
import os
import pandas as pd
import soundfile

# Loading the audio files using librosa
def loading(file):
    try:
        y, samplingRate = librosa.load(file, sr=None, mono=True)
        if y is None or len(y) == 0:
            raise ValueError("Audio signal is empty or invalid")
        return y, samplingRate
    except Exception as e:
        print(f"Error loading file {file}: {e}")
        return None, None
# Extract MFCC features
def extractMfcc(y, sr):
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)  # The first 13 MFCCs usually contain the most important information for classification
    mfccsMean = np.mean(mfccs, axis=1)  # Reduce dimensionality and capture a summary statistic of the audio signal
    return mfccsMean

# Extract chroma features
def extractChroma(y, sr):
    chroma = librosa.feature.chroma_stft(y=y, sr=sr)
    chromaMean = np.mean(chroma, axis=1)
    return chromaMean

# Extract spectral contrast features
def extractSpectral(y, sr):
    fmin = sr / 80  # Minimum frequency
    spectral_contrast = librosa.feature.spectral_contrast(y=y, sr=sr, fmin=fmin, n_bands=6)
    spectral_contrast_mean = np.mean(spectral_contrast, axis=1)
    return spectral_contrast_mean

# Extract zero-crossing rate feature
def extractZCR(y):
    zcr = librosa.feature.zero_crossing_rate(y=y)
    zcr_mean = np.mean(zcr)
    return zcr_mean

# Process data folder and extract features
def processDirectory(directory):
    featuresList = []  # List to store features
    labels = []  # List to store labels
    # Loop through every folder of data
    for label in os.listdir(directory):
        class_folder = os.path.join(directory, label)
        # Only process subfolders (classes)
        if os.path.isdir(class_folder):
            #print(f"Processing label: {label}")  # Print the label
            # Process every .wav file in the folder
            for filename in os.listdir(class_folder):
                if filename.endswith('.wav'):
                    file = os.path.join(class_folder, filename)
                    y, sr = loading(file)
                    if y is not None:  # Ensure audio was loaded successfully
                        mfccs = extractMfcc(y, sr)
                        chroma = extractChroma(y, sr)
                        spectral_contrast = extractSpectral(y, sr)
                        zcr = extractZCR(y)
                        # Combine all features into one list
                        features = np.hstack([mfccs, chroma, spectral_contrast, zcr])
                        # Add features to the corresponding label
                        featuresList.append(features)
                        labels.append(label)
                        # Print the features and label for each file
                        #print(f"File: {filename}")
                        #print(f"Label: {label}")
                    
    # Convert list of features and labels to pandas DataFrame
    df = pd.DataFrame(featuresList)
    df['label'] = labels  # Add labels as the last column
    return df

# Function to save the features to a CSV file
def saveCSV(df, csvFile):
    try:
        df.to_csv(csvFile, index=False)
        print(f"Features saved to {csvFile}")
    except Exception as e:
        print(f"Error saving CSV file: {e}")

def main():
    dataset = './data'
    csvFile = './features/extracted_features.csv'
    # Process dataset folder and get features as a DataFrame
    DFfeatures = processDirectory(dataset)
    # Save the features to a CSV file
    if not DFfeatures.empty:
        saveCSV(DFfeatures, csvFile)

if __name__ == "__main__":
    main()
