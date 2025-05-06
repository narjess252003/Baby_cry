# Get baby info by ID
@app.route('/get-baby/<int:id>', methods=['GET'])
def get_baby(id):
    try:
        cursor = mysql.cursor(MySQLdb.cursors.DictCursor)
        cursor.execute("SELECT * FROM baby_info WHERE id = %s", (id,))
        result = cursor.fetchone()
        cursor.close()

        if result:
            return jsonify({
                'id': result['id'],
                'full_name': result['full_name'],
                'age': result['age'],
                'nationality': result['nationality']
            })
        else:
            return jsonify({'error': 'Baby not found'}), 404
    except Exception as e:
        logging.error(f"Error fetching baby info: {str(e)}")
        return jsonify({'error': str(e)}), 500