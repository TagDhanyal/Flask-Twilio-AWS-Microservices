from pymongo import MongoClient
import boto3

# Create a Boto3 client for Systems Manager
ssm_client = boto3.client('ssm')

# Define the name of the parameter containing the MongoDB connection string
mongodb_parameter_name = '/mongodb-string'

# Connect to MongoDB
def get_mongodb_connection_string():
    try:
        response = ssm_client.get_parameter(Name=mongodb_parameter_name, WithDecryption=True)
        connection_string = response['Parameter']['Value']
        return connection_string
    except ssm_client.exceptions.ParameterNotFound:
        return None
    except Exception as e:
        print(f"Error retrieving MongoDB connection string: {str(e)}")
        return None

# Get the MongoDB connection string
mongodb_connection_string = get_mongodb_connection_string()

if mongodb_connection_string:
    try:
        client = MongoClient(mongodb_connection_string)
        db = client['purchase_db']

        # Drop the purchases collection if it exists
        if 'purchases' in db.list_collection_names():
            db.purchases.drop()

        # Create the purchases collection
        db.create_collection("purchases")

        # Insert sample data
        purchases = [
            {"name": "Product A", "amount": 10.99},
            {"name": "Product B", "amount": 19.99},
            {"name": "Product C", "amount": 5.99}
        ]
        db.purchases.insert_many(purchases)

        print("Sample data inserted successfully.")
    except Exception as e:
        print(f"Error connecting to MongoDB: {str(e)}")
else:
    print("MongoDB connection string not found in Parameter Store.")