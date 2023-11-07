from flask import Flask, request, jsonify
from datetime import date
import psycopg2
import os

app = Flask(__name__)

# Database connection parameters
db_endpoint = os.environ["db_endpoint"]
db_name = os.environ["db_name"]
db_user = os.environ["db_user"]
db_password = os.environ["db_password"]

# Function to establish a database connection
def connect_to_db():
    try:
        connection = psycopg2.connect(
            host=db_endpoint,
            database=db_name,
            user=db_user,
            password=db_password
        )
        return connection
    except Exception as error:
        return None

# SQL statement to create the "users" table
create_table_sql = """
CREATE TABLE IF NOT EXISTS users (
    id serial PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    dob DATE
);
"""

# Connect to the PostgreSQL database
try:
    connection = connect_to_db()
    cursor = connection.cursor()

    # Create the "users" table
    cursor.execute(create_table_sql)
    connection.commit()
    print("Table 'users' created successfully.")

except (Exception, psycopg2.Error) as error:
    print(f"Error: {error}")

@app.route('/ready', methods=['GET'])
def liveness():
    return "OK", 200

# API to save/update user's name and date of birth
@app.route('/hello', methods=['POST', 'PUT'])
def save_update_user():
    data = request.get_json()

    if 'user_id' not in data:
        return jsonify({'error': 'User ID is required'}), 400

    user_id = data['user_id']
    name = data.get('name', '')
    dob = data.get('dob', '')

    connection = connect_to_db()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT id FROM users WHERE id = %s", (user_id,))
            user_exists = cursor.fetchone()

            if request.method == 'POST':
                if user_exists:
                    return jsonify({'error': 'User already exists'}), 409

                cursor.execute("INSERT INTO users (id, name, dob) VALUES (%s, %s, %s)",
                               (user_id, name, dob))
            elif request.method == 'PUT':
                if not user_exists:
                    return jsonify({'error': 'User does not exist'}), 404

                cursor.execute("UPDATE users SET name = %s, dob = %s WHERE id = %s",
                               (name, dob, user_id))

            connection.commit()
            cursor.close()
            return jsonify({'message': 'User information saved/updated successfully'}), 200
        except Exception as error:
            return jsonify({'error': str(error)}), 500
        finally:
            connection.close()
    else:
        return jsonify({'error': 'Failed to connect to the database'}), 500

# New route to get user information by user_id 
@app.route('/hello/<int:user_id>', methods=['GET'])
def get_user_by_id(user_id):
    connection = connect_to_db()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT id, name, dob FROM users WHERE id = %s;", (user_id,))
            user_data = cursor.fetchone()

            if user_data:
                user_id, name, dob = user_data
                user_info = {
                    'dob': dob
                }
                return jsonify(user_info), 200
            else:
                return jsonify({'error': 'User not found'}), 404
        except Exception as error:
            return jsonify({'error': str(error)}), 500
        finally:
            connection.close()
    else:
        return jsonify({'error': 'Failed to connect to the database'}), 500


@app.route('/hello/age/<int:user_id>', methods=['GET'])
def calculate_user_age(user_id):
    connection = connect_to_db()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT id, name, dob FROM users WHERE id = %s", (user_id,))
            user_data = cursor.fetchone()


            def numOfDays(current_date, birthday):
            #check which date is greater to avoid days output in -ve number
                if current_date > birthday:
                    return (current_date-birthday).days
                else:
                    return "NEM"
            if user_data:
                user_id, name, dob = user_data
                current_date = date.today()

                current_year = int(current_date.strftime("%Y"))
                current_month = int(dob.strftime("%m"))
                current_day = int(dob.strftime("%d"))

                dateWithCurrentYear = date(current_year, current_month, current_day)
                # Check if the birthday is today
                if dateWithCurrentYear == current_date:
                    return jsonify({
                        "message": f"Hello, {name}! Happy birthday!"
                    }), 200
                return jsonify({
                "message": f"Hello, {name}!Your birthday is in {numOfDays(current_date, dateWithCurrentYear)} day(s)"
            }), 200
            else:
                return jsonify({'error': 'User not found'}), 404
        except Exception as error:
            return jsonify({'error': str(error)}), 500
        finally:
            connection.close()
    else:
        return jsonify({'error': 'Failed to connect to the database'}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)