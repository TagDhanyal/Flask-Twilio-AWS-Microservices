import boto3
from flask import Flask, jsonify, request
from flask_cors import CORS
from pymongo import MongoClient
from bson.objectid import ObjectId

app = Flask(__name__)
cors = CORS(app)

# Create a Boto3 client for Systems Manager
ssm_client = boto3.client('ssm')

# Define the name of the parameter containing the MongoDB connection string
mongodb_parameter_name = '/your-mongodb-parameter-name'

# Fetch the MongoDB connection string from AWS Systems Manager Parameter Store
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
        # Create a MongoDB client
        client = MongoClient(mongodb_connection_string)
        db = client['your-database-name']
        collection = db['purchases']
    except Exception as e:
        print(f"Error connecting to MongoDB: {str(e)}")
        collection = None
else:
    print("MongoDB connection string not found in Parameter Store.")
    collection = None

@app.route("/api/purchase/save_purchase", methods=["POST"])
def save_purchase():
    if collection is None:
        return jsonify({'message': 'MongoDB connection error'}), 500

    data = request.json
    name = data.get('name')
    product = data.get('product')

    # Custom logic to calculate amount based on product
    if product == 'Product A':
        amount = 10.99
    elif product == 'Product B':
        amount = 19.99
    elif product == 'Product C':
        amount = 5.99
    else:
        return jsonify({'message': 'Invalid product'}), 400

    # Insert the purchase into the MongoDB collection
    purchase = {
        'name': name,
        'amount': amount
    }
    collection.insert_one(purchase)

    return jsonify({'message': 'Purchase saved successfully'}), 200

@app.route("/api/purchase/get_purchases", methods=["GET"])
def get_purchases():
    if collection is None:
        return jsonify({'message': 'MongoDB connection error'}), 500

    purchases = list(collection.find())
    purchases_dict = [{'id': str(purchase['_id']), 'name': purchase['name'], 'amount': purchase['amount']} for purchase in purchases]

    return jsonify(purchases_dict), 200

@app.route("/api/purchase/delete_purchase/<string:purchase_id>", methods=["DELETE"])
def delete_purchase(purchase_id):
    if collection is None:
        return jsonify({'message': 'MongoDB connection error'}), 500

    result = collection.delete_one({'_id': ObjectId(purchase_id)})

    if result.deleted_count == 1:
        return jsonify({'message': 'Purchase deleted successfully'}), 200
    else:
        return jsonify({'message': 'Purchase not found'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)