User Information API
This Python project implements a simple Flask-based RESTful API for managing user information, including their name and date of birth, with a PostgreSQL database as the backend. The API supports creating, updating, retrieving user information, and calculating the user's next birthday.

Prerequisites
Python 3.x
Flask
psycopg2
PostgreSQL


Setup
Environment Variables
Ensure the following environment variables are set in your system to allow the application to connect to the PostgreSQL database:

db_endpoint: Database endpoint (hostname or IP address)
db_name: Database name
db_user: Database user
db_password: Database password
Installation
Clone the repository:

```bash
git clone <repository_url>
cd <repository_directory>
```

Create a virtual environment and activate it:

```bash
python3 -m venv venv
source venv/bin/activate
```

Install the required dependencies:

```bash
pip install -r requirements.txt
```

Database Setup
The application will automatically create a users table if it does not exist. The table structure is as follows:

```sql
CREATE TABLE IF NOT EXISTS users (
    id serial PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    dob DATE
);
```

Running the Application
To run the Flask application, execute the following command:

bash
python app.py


The application will be accessible at http://0.0.0.0:5000.

API Endpoints

1. Health Check
Endpoint: /ready
Method: GET
Description: Returns a 200 OK status to indicate the API is running.

2. Save/Update User Information
Endpoint: /hello

Method: POST or PUT

Description: Saves or updates a user's name and date of birth.

Request Body:

```json
{
    "user_id": 1,
    "name": "John Doe",
    "dob": "1990-01-01"
}
```

Responses:

200 OK: User information saved/updated successfully.
400 Bad Request: User ID is required.
404 Not Found: User does not exist (for PUT method).
409 Conflict: User already exists (for POST method).
500 Internal Server Error: Database connection or query error.

3. Get User Information by ID
Endpoint: /hello/<int:user_id>

Method: GET

Description: Retrieves user information by user ID.

Response:

```json

{
    "dob": "1990-01-01"
}
```

200 OK: User information retrieved successfully.
404 Not Found: User not found.
500 Internal Server Error: Database connection or query error.

4. Calculate User's Next Birthday
Endpoint: /hello/age/<int:user_id>

Method: GET

Description: Calculates the number of days until the user's next birthday or wishes them if today is their birthday.

Response:

```json

{
    "message": "Hello, John Doe! Your birthday is in 30 day(s)"
}
```

200 OK: User's next birthday calculated successfully.
404 Not Found: User not found.
500 Internal Server Error: Database connection or query error.

Error Handling

The API provides meaningful error messages and appropriate HTTP status codes for different error scenarios, such as invalid input, resource not found, and database connection issues.