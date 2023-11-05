import os

# Specify the file path
file_path = '/Users/seba/sebastian/birthday-app/helm/test.env'
variable_name = 'MY_ENV_VAR_NAME'

# Check if the file exists
if os.path.exists(file_path):
    with open(file_path, 'r') as file:
        # Read the content of the file
        variable_value = file.read().strip()

        # Set the environment variable
        os.environ[variable_name] = variable_value

        # Print a confirmation message
        print(f"Environment variable {variable_name} set to {variable_value}")
else:
    print(f"File not found: {file_path}")

