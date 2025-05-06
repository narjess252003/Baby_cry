import datetime
from mailbox import Babyl
import sys
import os
import logging
import random
from werkzeug.utils import secure_filename
from pydub import AudioSegment
import datetime
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import time
import smtplib
from email.message import EmailMessage
import soundfile as sf
from pydub import AudioSegment
import bcrypt
import wave
import joblib
from datetime import datetime
import secrets
from flask_mail import Mail, Message
import librosa
import pandas as pd
from twilio.rest import Client
import numpy as np
from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import MySQLdb
import vonage  # Import MySQLdb for database operations
from flask import send_from_directory

db = SQLAlchemy()
# Add custom module paths
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
features_path = os.path.join(backend_path, "features")
sys.path.append(backend_path)
sys.path.append(features_path)

otp_store = {}
otp_expiry_time = 300
from features.featuresExtraction import extractMfcc, extractChroma, extractSpectral, extractZCR, loading

# Initialize Flask application
app = Flask(__name__, template_folder="C:/xamppp/htdocs/baby_cries_classification/backend/templates")
logging.basicConfig(level=logging.INFO)
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
CORS(app)

# Configure MySQL database connection
app.config['MYSQL_HOST'] = 'localhost'
app.config['MYSQL_USER'] = 'root'  # Default MySQL user
app.config['MYSQL_PASSWORD'] = ''  # Default MySQL password
app.config['MYSQL_DB'] = 'babies_cries'  # Database name
mail = Mail(app)
mysql = MySQLdb.connect(
    host=app.config['MYSQL_HOST'],
    user=app.config['MYSQL_USER'],
    passwd=app.config['MYSQL_PASSWORD'],
    db=app.config['MYSQL_DB']
)
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql://root:@localhost/babies_cries'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)


# Twilio credentials (à stocker en sécurité !)
account_sid = 'AC601aeca873ce05a1b1a46ae1372164ba'
auth_token = '0888188f2860c73a0322d4cc56054499'
twilio_number = 'YOUR_TWILIO_PHONE_NUMBER'
# Load the machine learning model
model_path = "C:/xamppp/htdocs/baby_cries_classification/backend/model/random_forest_model.pkl"
model = joblib.load(model_path)

# Configure upload folder
UPLOAD_FOLDER = "C:/xamppp/htdocs/baby_cries_classification/backend/uploads"
ALLOWED_EXTENSIONS = {'wav','aac', 'jpg', 'jpeg', 'png', 'gif'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# MySQL connection setup
def get_db_connection():
    connection = MySQLdb.connect(
        host='localhost',        # Your MySQL host (usually 'localhost' for local development)
        user='root',             # Your MySQL username
        passwd='',               # Your MySQL password (blank if no password set)
        db='babies_cries'        # Replace with your database name
    )
    return connection

class Babyl(db.Model):
    __tablename__ = 'babies'

    id = db.Column(db.Integer, primary_key=True)
    first_name = db.Column(db.String(80), nullable=False)
    last_name = db.Column(db.String(80), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    nationality = db.Column(db.String(80), nullable=False)
    health_status = db.Column(db.String(80), nullable=False)
    mother_id = db.Column(db.Integer, db.ForeignKey('baby_info.id'), nullable=False)
    profile_picture_path = db.Column(db.String(255), nullable=True)

    # Define the relationship to the Mother model
    mother = db.relationship('Mother', backref=db.backref('babies', lazy=True))

class Mother(db.Model):
    __tablename__ = 'baby_info'

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), nullable=False)
    phone_number = db.Column(db.String(15), nullable=False)
    date_of_birth = db.Column(db.String(10), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    nationality = db.Column(db.String(50), nullable=False)
    job_status = db.Column(db.String(10), nullable=False)
    job_title = db.Column(db.String(100))
    time_outside_home = db.Column(db.String(50))
    additional_info = db.Column(db.String(200))

    def __repr__(self):
        return f"<Mother {self.email}>"
    
# Define the CryPrediction model
class CryPrediction(db.Model):
    __tablename__ = 'cry_predictions'

    id = db.Column(db.Integer, primary_key=True)
    baby_id = db.Column(db.Integer, nullable=False)
    audio_path = db.Column(db.String(255), nullable=True)
    prediction = db.Column(db.String(50), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

# Route to get predictions for a particular baby and their statistics
@app.route('/get_cry_stats/<int:baby_id>', methods=['GET'])
def get_cry_stats(baby_id):
    try:
        # Get stats: count by prediction
        prediction_counts = (
            db.session.query(CryPrediction.prediction, db.func.count(CryPrediction.prediction))
            .filter_by(baby_id=baby_id)
            .group_by(CryPrediction.prediction)
            .all()
        )
        
        # Log the prediction counts to check what is being returned
        app.logger.info(f"Prediction counts for baby {baby_id}: {prediction_counts}")
        
        stats = {
            'hungry': 0,
            'tired': 0,
            'belly_pain': 0,
            'burping': 0,
            'discomfort': 0,
        }

        for prediction, count in prediction_counts:
            if prediction in stats:
                stats[prediction] = count

        # Log the stats to verify correct data
        app.logger.info(f"Stats for baby {baby_id}: {stats}")

        # Get full history
        predictions = CryPrediction.query.filter_by(baby_id=baby_id).order_by(CryPrediction.timestamp.desc()).all()
        history = [
            {
                'id': p.id,
                'prediction': p.prediction,
                'audio_path': p.audio_path,
                'timestamp': p.timestamp.strftime('%Y-%m-%d %H:%M:%S')
            }
            for p in predictions
        ]

        return jsonify({'stats': stats, 'history': history}), 200

    except Exception as e:
        app.logger.error(f"Error fetching cry stats for baby {baby_id}: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/mother/update/<int:id>', methods=['PUT'])
def update_mother_profile(id):
    # Get the data from the request
    data = request.get_json()

    # Fetch the mother from the database using Session.get()
    with db.session() as session:
        mother = session.get(Mother, id)
        if not mother:
            return jsonify({"message": "Mother not found"}), 404

        # Update the mother's information
        mother.email = data.get('email', mother.email)
        mother.phone_number = data.get('phone_number', mother.phone_number)
        mother.date_of_birth = data.get('date_of_birth', mother.date_of_birth)
        mother.age = data.get('age', mother.age)
        mother.nationality = data.get('nationality', mother.nationality)
        mother.job_status = data.get('job_status', mother.job_status)
        mother.job_title = data.get('job_title', mother.job_title)
        mother.time_outside_home = data.get('time_outside_home', mother.time_outside_home)
        mother.additional_info = data.get('additional_info', mother.additional_info)

        # Commit the changes to the database
        session.commit()

    return jsonify({"message": "Profile updated successfully"}), 200

@app.route('/uploads/<path:filename>', methods=['GET'])
def serve_profile_pic(filename):
    try:
        return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
    except Exception as e:
        logging.error(f"Error serving file {filename}: {e}")
        return jsonify({"error": "File not found"}), 404

@app.route('/api/mother/<int:mother_id>/upload_profile_pic', methods=['POST'])
def upload_profile_picture(mother_id):
    if 'image' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    # Save the file
    filename = secure_filename(f'mother_{mother_id}_{file.filename}')
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(file_path)

    # Save the file path to the database
    relative_path = f"uploads/{filename}"
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('UPDATE baby_info SET profile_picture = %s WHERE id = %s', (relative_path, mother_id))
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({'message': 'Profile picture uploaded successfully', 'profile_picture': relative_path}), 200
    except Exception as e:
        logging.error(f"Error uploading profile picture: {e}")
        return jsonify({'error': str(e)}), 500
    

def convert_to_wav(src_path, dst_path):
    sound = AudioSegment.from_file(src_path)
    sound = sound.set_frame_rate(22050).set_channels(1)  # pour assurer la compatibilité avec librosa
    sound.export(dst_path, format="wav")

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


@app.route('/delete_baby/<int:baby_id>', methods=['DELETE'])
def delete_baby(baby_id):
    baby = Babyl.query.get(baby_id)  # Use the correct model name 'Babyl'
    if not baby:
        return jsonify({"message": "Baby not found"}), 404

    db.session.delete(baby)
    db.session.commit()

    return jsonify({"message": "Baby profile deleted successfully"}), 200
# Helper function to load and preprocess audio
def load_audio(file_path):
    try:
        try:
            # Try to use soundfile first
            with sf.SoundFile(file_path) as f:
                y, sr = librosa.load(file_path, sr=None, mono=True)
        except RuntimeError as sf_error:
            logging.warning(f"SoundFile failed: {sf_error}, trying audioread fallback")
            y, sr = librosa.load(file_path, sr=None, mono=True)  # audioread fallback

        if y is None or len(y) == 0:
            raise ValueError("Audio signal is empty or invalid")
        return y, sr
    except Exception as e:
        raise ValueError(f"Error loading audio file: {str(e)}")
# Preprocess audio features for prediction
def preprocess_audio_features(file_path):
    try:
        y, sr = loading(file_path)
        if y is None or sr is None:
            raise ValueError("Error loading audio file")

        # Extract features
        mfcc = extractMfcc(y, sr).flatten()
        chroma = extractChroma(y, sr).flatten()
        spectral_contrast = extractSpectral(y, sr).flatten()
        zcr = extractZCR(y).flatten()

        # Combine extracted features into a single array
        features = np.hstack([mfcc, chroma, spectral_contrast, zcr]).astype(np.float32)
        return features
    except Exception as e:
        raise ValueError(f"Error processing audio file: {str(e)}")


@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    return send_from_directory('uploads', filename)

@app.route('/get_pictures', methods=['GET'])
def get_pictures():
    baby_id = request.args.get('baby_id')
    if not baby_id:
        return jsonify({"error": "baby_id is required"}), 400

    try:
        cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute("SELECT file_path FROM album_pictures WHERE baby_id = %s", (baby_id,))
        pictures = cursor.fetchall()
        cursor.close()

        base_url = "http://192.168.1.10:5000"
        image_urls = [f"{base_url}/uploads/{os.path.basename(p['file_path'])}" for p in pictures]

        return jsonify(image_urls), 200
    except Exception as e:
        logging.error(f"Error fetching pictures: {e}")
        return jsonify({"error": str(e)}), 500
@app.route('/upload_picture', methods=['POST'])
def upload_picture():
    try:
        baby_id = request.form.get('baby_id')
        if 'file' not in request.files:
            return jsonify({'error': 'No file part'}), 400

        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'No selected file'}), 400

        filename = secure_filename(file.filename)
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(file_path)

        cursor = mysql.cursor()
        cursor.execute(
            'INSERT INTO album_pictures (baby_id, file_path) VALUES (%s, %s)',
            (baby_id, file_path)
        )
        mysql.commit()
        cursor.close()

        return jsonify({'message': 'Image uploaded successfully'}), 200
    except Exception as e:
        logging.error(f"Error uploading image: {e}")
        return jsonify({'error': str(e)}), 500
# Endpoint to upload and save the audio file
@app.route('/upload', methods=['POST'])
def upload_file():
    try:
        # Validate file upload
        if 'file' not in request.files:
            return jsonify({"error": "No file uploaded"}), 400

        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400

        # Save file to the uploads folder
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        saved_filename = f"{timestamp}_{file.filename}"
        file_path = os.path.join(UPLOAD_FOLDER, saved_filename)
        file.save(file_path)

        # Return the server path of the file
        logging.info(f"File saved at {file_path}")
        return jsonify({"message": "File uploaded successfully!", "file_path": file_path}), 200

    except Exception as e:
        logging.error(f"Error uploading file: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/delete_image', methods=['DELETE'])
def delete_image():
    try:
        # Get the image file_path from the JSON body
        data = request.get_json()  # Parse the JSON body
        file_path = data.get('file_path')  # Extract file_path from the JSON body

        if not file_path:
            return jsonify({"error": "File path is required"}), 400

        # Delete the image from the database
        cursor = mysql.cursor()
        cursor.execute("DELETE FROM album_pictures WHERE file_path = %s", (file_path,))
        mysql.commit()
        cursor.close()

        return jsonify({"message": "Image deleted successfully!"}), 200
    except Exception as e:
        logging.error(f"Error deleting image: {e}")
        return jsonify({"error": str(e)}), 500

 
@app.route('/update-note', methods=['PUT'])
def update_note():
    try:
        data = request.get_json()
        picture_id = data.get('id')
        note = data.get('note')

        if not picture_id:
            return jsonify({"error": "Picture ID is required"}), 400
        if note is None:  # Allow empty note but ensure key exists
            return jsonify({"error": "Note is required"}), 400

        cursor = mysql.cursor()
        cursor.execute("UPDATE album_pictures SET note = %s WHERE id = %s", (note, picture_id))
        mysql.commit()
        cursor.close()
        return jsonify({"message": "Note updated successfully!"}), 200
    except Exception as e:
        logging.error(f"Error updating note: {e}")
        return jsonify({"error": str(e)}), 500

# Endpoint to save pictures and notes for a user
@app.route('/save-picture', methods=['POST'])
def save_picture():
    try:
        user_id = request.form.get('user_id')
        logging.info(f"Received user_id: {user_id}")  # Debug log
        if not user_id:
            logging.error("User ID is required but not provided")
            return jsonify({"error": "User ID is required"}), 400

        note = request.form.get('note', '')
        if 'file' not in request.files:
            return jsonify({"error": "No file uploaded"}), 400

        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No selected file"}), 400

        # Save file
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        filename = f"{timestamp}_{file.filename}"
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(file_path)

        # Insert into database
        cursor = mysql.cursor()
        cursor.execute(
            "INSERT INTO album_pictures (user_id, file_path, note) VALUES (%s, %s, %s)",
            (user_id, f"uploads/{filename}", note)
        )
        mysql.commit()
        cursor.close()

        logging.info(f"Picture saved for user_id {user_id} with file_path {file_path}")
        return jsonify({"message": "Picture saved successfully!", "file_path": f"uploads/{filename}"}), 200
    except Exception as e:
        logging.error(f"Error saving picture: {e}")
        return jsonify({"error": str(e)}), 500

# Endpoint to serve uploaded files
@app.route('/uploads/<filename>', methods=['GET'])
def serve_uploaded_file(filename):
    try:
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        logging.info(f"Serving file from: {file_path}")
        return send_from_directory(UPLOAD_FOLDER, filename)
    except Exception as e:
        logging.error(f"Error serving file {filename}: {e}")
        return jsonify({"error": "File not found"}), 404


@app.route('/add_baby', methods=['POST'])
def add_baby():
    try:
        data = request.get_json()
        logging.info(f"Received data: {data}")  # Debug log

        # Extract fields from the request
        first_name = data.get('first_name')
        last_name = data.get('last_name')
        age = data.get('age')
        nationality = data.get('nationality')
        health_status = data.get('health_status')
        mother_id = data.get('mother_id')

        # Check for missing fields
        missing_fields = []
        if not first_name:
            missing_fields.append("first_name")
        if not last_name:
            missing_fields.append("last_name")
        if not age:
            missing_fields.append("age")
        if not nationality:
            missing_fields.append("nationality")
        if not health_status:
            missing_fields.append("health_status")
        if not mother_id:
            missing_fields.append("mother_id")

        if missing_fields:
            logging.error(f"Missing required fields: {', '.join(missing_fields)}")
            return jsonify({'error': f"Missing required fields: {', '.join(missing_fields)}"}), 400

        # Insert data into the database
        connection = mysql.cursor()
        query = '''
        INSERT INTO babies (first_name, last_name, age, nationality, health_status, mother_id)
        VALUES (%s, %s, %s, %s, %s, %s)
        '''
        connection.execute(query, (first_name, last_name, age, nationality, health_status, mother_id))
        mysql.commit()
        connection.close()

        return jsonify({'message': 'Baby added successfully!'}), 201
    except Exception as e:
        logging.error(f"Error adding baby: {e}")
        return jsonify({'error': str(e)}), 500
    
@app.route('/api/mother/<int:mother_id>', methods=['GET'])
def get_mother_info(mother_id):
    try:
        cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute("SELECT * FROM baby_info WHERE id = %s", (mother_id,))
        mother = cursor.fetchone()
        cursor.close()

        if mother:
            if mother.get('profile_picture'):
                # Add the base URL in the profile_picture path
                mother['profile_picture'] = f"http://192.168.1.10:5000/{mother['profile_picture']}"
            return jsonify(mother), 200
        else:
            return jsonify({'error': 'Mother not found'}), 404
    except Exception as e:
        logging.error(f"Error fetching mother info: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/get_images/<int:baby_id>', methods=['GET'])
def get_images(baby_id):
    try:
        cursor = mysql.cursor()  # Use mysql.cursor() instead of mysql.connection.cursor()
        cursor.execute('SELECT file_path FROM album_pictures WHERE baby_id = %s', (baby_id,))
        images = cursor.fetchall()
        cursor.close()  # Always close the cursor after use
        return jsonify([{'file_path': image[0]} for image in images]), 200
    except Exception as e:
        logging.error(f"Error fetching images: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/upload_image', methods=['POST'])
def upload_image():
    try:
        data = request.get_json()
        baby_id = data['baby_id']
        file_path = data['file_path']

        cursor = mysql.cursor()  # Use mysql.cursor() instead of mysql.connection.cursor()
        cursor.execute('INSERT INTO album_pictures (baby_id, file_path) VALUES (%s, %s)', (baby_id, file_path))
        mysql.commit()
        cursor.close()  # Always close the cursor after use

        return jsonify({'message': 'Image uploaded successfully'}), 200
    except Exception as e:
        logging.error(f"Error uploading image: {e}")
        return jsonify({'error': str(e)}), 500
    
@app.route('/get_babies', methods=['GET'])
def get_babies():
    user_id = request.args.get('user_id')
    if not user_id:
        return jsonify({'error': 'user_id is required'}), 400

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        cursor.execute("SELECT id, email FROM baby_info WHERE user_id = %s", (user_id,))
        babies = cursor.fetchall()
        return jsonify(babies)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cursor.close()
        conn.close()

# Predict audio file
@app.route('/predict', methods=['POST'])
def predict():
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file provided"}), 400

        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No file selected"}), 400

        # Fix missing extensions
        filename = secure_filename(file.filename)
        if not '.' in filename:
            mime_type = file.mimetype
            if mime_type == 'audio/wav':
                filename += '.wav'
            elif mime_type == 'audio/aac' or mime_type == 'audio/x-aac':
                filename += '.aac'
            else:
                return jsonify({"error": "Unsupported MIME type."}), 400

        file_path = os.path.join(UPLOAD_FOLDER, filename)
        file.save(file_path)

        if filename.lower().endswith('.aac'):
            wav_path = file_path.replace('.aac', '.wav')
            convert_to_wav(file_path, wav_path)
            file_path = wav_path

        # Preprocess and predict
        y, sr = load_audio(file_path)
        features = preprocess_audio_features(file_path)
        features_df = pd.DataFrame(features.reshape(1, -1))
        prediction = model.predict(features_df)[0]

        return jsonify({
            "prediction": str(prediction),
            "message": "Prediction successful"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
@app.route('/generateOTP', methods=['POST'])
def generate_otp():
    data = request.get_json()
    email = data.get('email')

    if not email:
        return jsonify({'status': 'failure', 'message': 'Email is required'}), 400

    otp_code = str(random.randint(100000, 999999))
    timestamp = int(time.time())

    cursor = mysql.cursor()
    try:
        # Vérifier si l'utilisateur existe
        cursor.execute("SELECT id FROM baby_info WHERE email = %s", (email,))
        user = cursor.fetchone()

        if not user:
            return jsonify({'status': 'failure', 'message': 'User not found'}), 404

        # Mise à jour du code de vérification et de la date de création
        cursor.execute("""
            UPDATE baby_info
            SET verification_code = %s, created_at = FROM_UNIXTIME(%s)
            WHERE email = %s
        """, (otp_code, timestamp, email))
        mysql.commit()

        logging.info(f"Generated OTP for {email}: {otp_code}, Timestamp: {timestamp}")
        return jsonify({'status': 'OTP sent to email'}), 200
    except Exception as e:
        logging.error(f"Error generating OTP: {e}")
        return jsonify({'error': 'Failed to generate OTP'}), 500
    finally:
        cursor.close()

@app.route('/verifyOTP', methods=['POST'])
def verify_otp():
    data = request.get_json()
    email = data.get('email')
    otp_code = data.get('otp')

    if not email or not otp_code:
        return jsonify({'status': 'failure', 'message': 'Email and OTP are required'}), 400

    cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
    try:
        cursor.execute("SELECT verification_code, UNIX_TIMESTAMP(created_at) AS timestamp FROM baby_info WHERE email = %s", (email,))
        result = cursor.fetchone()

        if not result:
            return jsonify({'status': 'failure', 'message': 'User not found'}), 404

        stored_otp = result['verification_code']
        timestamp = result['timestamp']

        if time.time() - timestamp > otp_expiry_time:
            return jsonify({'status': 'failure', 'message': 'OTP expired'}), 400

        if otp_code == stored_otp:
            cursor.execute("UPDATE baby_info SET is_verified = 1 WHERE email = %s", (email,))
            mysql.commit()
            return jsonify({'status': 'success'}), 200
        else:
            return jsonify({'status': 'failure', 'message': 'Invalid OTP'}), 400
    except Exception as e:
        logging.error(f"Error verifying OTP: {e}")
        return jsonify({'error': 'Failed to verify OTP'}), 500
    finally:
        cursor.close()

@app.route('/register-baby', methods=['POST'])
def register_baby():
    data = request.get_json()

    # Log the received data
    logging.debug(f"== Données reçues du frontend ==\n{data}")

    email = data.get('email')
    password = data.get('password')
    phone = data.get('phone_number')
    date_of_birth = data.get('birth_date')
    nationality = data.get('nationality')
    profession = data.get('profession')  # Correspond à job_title
    job_status = data.get('job_status', 'working')  # Par défaut "working", tu peux adapter
    time_outside_home = data.get('duration_outside')
    additional_info = data.get('additional_info')

    # Vérification des champs obligatoires
    if not all([email, password, phone, date_of_birth]):
        logging.error("Missing required fields.")
        return jsonify({'error': 'Email, password, phone, and date_of_birth are required'}), 400

    # Valider et convertir la date de naissance
    try:
        birth_date = datetime.fromisoformat(date_of_birth)
    except ValueError as e:
        logging.error(f"Invalid date of birth format: {e}")
        return jsonify({'error': 'Invalid date format'}), 400

    # Calculer l’âge
    today = datetime.today()
    age = today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))

    cursor = mysql.cursor()
    try:
        # Vérifier si l'email existe déjà
        cursor.execute("SELECT * FROM baby_info WHERE email = %s", (email,))
        existing_user = cursor.fetchone()
        if existing_user:
            logging.warning(f"Email {email} already registered.")
            return jsonify({'error': 'Email is already registered'}), 400

        # Générer OTP et hasher le mot de passe
        otp = str(random.randint(100000, 999999))
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        # Insérer l'utilisateur dans la base de données
        cursor.execute("""
            INSERT INTO baby_info (
                email, password, phone_number, verification_code, is_verified,
                date_of_birth, age, nationality, job_status, job_title,
                time_outside_home, additional_info
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            email, hashed_password, phone, otp, False,
            birth_date, age, nationality, job_status, profession,
            time_outside_home, additional_info
        ))
        mysql.commit()

        logging.info(f"User {email} registered successfully with OTP {otp}.")
        send_email_otp(email, otp)

        return jsonify({'message': 'OTP sent to email and phone'}), 200

    except Exception as e:
        mysql.rollback()
        logging.error(f"Error in register_baby: {e}")
        return jsonify({'error': 'Registration failed'}), 500
    finally:
        cursor.close()
        logging.debug("Cursor closed.")
        
def send_email_otp(to_email, otp_code):
    email_address = 'narjessbeltaief14@gmail.com'
    email_password = 'cmno jvkj dmqp abky'  # <-- Use the 16-character App Password

    msg = EmailMessage()
    msg['Subject'] = 'Your BabyCryApp Verification Code'
    msg['From'] = email_address
    msg['To'] = to_email
    msg.set_content(f'Hello,\n\nYour verification code is: {otp_code}\n\nThanks!')

    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
        smtp.login(email_address, email_password)
        smtp.send_message(msg)

@app.route('/login-baby', methods=['POST'])
def login_baby():
    try:
        # Get data from request
        data = request.get_json()
        email = data.get('email')
        password = data.get('password')

        # Ensure email and password are provided
        if not email or not password:
            return jsonify({'message': 'Email and password are required'}), 400

        # Query database for authentication
        cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute("SELECT * FROM baby_info WHERE email = %s", (email,))
        result = cursor.fetchone()
        cursor.close()

        # Check if user exists
        if result:
            # Check if the provided password matches the hashed password in the database
            stored_password = result['password']
            if bcrypt.checkpw(password.encode('utf-8'), stored_password.encode('utf-8')):
                return jsonify({
                    'message': 'Login successful!',
                    'user': {
                        'id': result['id'],
                        'email': result['email']
                    }
                }), 200
            else:
                return jsonify({'message': 'Invalid password'}), 401
        else:
            return jsonify({'message': 'Invalid email or password'}), 401

    except MySQLdb.MySQLError as db_error:
        logging.error(f"Database error: {str(db_error)}")
        return jsonify({'error': 'Database error occurred. Please try again later.'}), 500

    except Exception as e:
        logging.error(f"Login error: {str(e)}")
        print(f"Login error: {str(e)}")
        return jsonify({'error': 'An error occurred during login. Please try again later.'}), 500

@app.route('/get_babies_by_mother/<int:mother_id>', methods=['GET'])
def get_babies_by_mother(mother_id):
    try:
        # Retrieve babies associated with the given mother_id
        babies = Babyl.query.filter_by(mother_id=mother_id).all()
        
        # Prepare a response containing the babies' data
        babies_data = []
        for baby in babies:
            baby_info = {
                'id': baby.id,
                'first_name': baby.first_name,
                'last_name': baby.last_name,
                'age': baby.age,
                'nationality': baby.nationality,
                'health_status': baby.health_status
            }
            babies_data.append(baby_info)

        return jsonify({'babies': babies_data}), 200
    except Exception as e:
        logging.error(f"Error fetching babies: {e}")
        return jsonify({"error": str(e)}), 500
@app.route('/get_baby_profile/<int:baby_id>', methods=['GET'])
def get_baby_profile(baby_id):
    try:
        cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute("SELECT * FROM babies WHERE id = %s", (baby_id,))
        result = cursor.fetchone()
        cursor.close()

        if result:
            profile_picture_url = None
            if result['profile_picture_path']:
                # ✅ Only return the relative path
                profile_picture_url = f"/uploads/{os.path.basename(result['profile_picture_path'])}"

            return jsonify({
                'id': result['id'],
                'first_name': result['first_name'],
                'last_name': result['last_name'],
                'age': result['age'],
                'nationality': result['nationality'],
                'health_status': result['health_status'],
                'profile_picture_url': profile_picture_url
            }), 200
        else:
            return jsonify({'error': 'Baby not found'}), 404
    except Exception as e:
        logging.error(f"Error fetching baby profile: {str(e)}")
        return jsonify({'error': str(e)}), 500

# Get baby info by ID
@app.route('/get-baby/<int:id>', methods=['GET'])
def get_baby(id):
    try:
        cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute("SELECT * FROM babies WHERE id = %s", (id,))  # Use the correct table name
        result = cursor.fetchone()
        cursor.close()

        if result:
            return jsonify({
                'id': result['id'],
                'first_name': result['first_name'],
                'last_name': result['last_name'],
                'age': result['age'],
                'nationality': result['nationality'],
                'health_status': result['health_status']
            }), 200
        else:
            return jsonify({'error': 'Baby not found'}), 404
    except Exception as e:
        logging.error(f"Error fetching baby info: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/save_prediction', methods=['POST'])
def save_prediction():
    data = request.get_json()
    baby_id = data.get('baby_id')
    audio_path = data.get('audio_path')
    prediction = data.get('prediction')
    timestamp = data.get('timestamp', datetime.now().isoformat())

    try:
        cursor = mysql.cursor()  # Use mysql.cursor() instead of mysql.connection.cursor()
        cursor.execute("""
            INSERT INTO cry_predictions (baby_id, prediction, audio_path, timestamp)
            VALUES (%s, %s, %s, %s)
        """, (baby_id, prediction, audio_path, timestamp))
        mysql.commit()
        cursor.close()
        return jsonify({'message': 'Prediction saved successfully'}), 200
    except Exception as e:
        logging.error(f"Error saving prediction: {e}")
        return jsonify({'error': str(e)}), 500
# Index route
@app.route('/')
def index():
    return render_template('index.html')


# Run the app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
