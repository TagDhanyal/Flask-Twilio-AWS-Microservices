from flask import Flask, request, jsonify
import pika, boto3
from botocore.exceptions import ClientError
import os
from flask_cors import CORS
import requests, json

app = Flask(__name__)
CORS(app)

mailtrap_name = os.environ['MAILTRAP_NAME']
mailtrap_password = os.environ['MAILTRAP_PASS']

ssm_client = boto3.client('ssm')
try:# Set up RabbitMQ connection
    amqp_url = ssm_client.get_parameter(Name='/rabbitmq/CLOUDAMQP_URL', WithDecryption=True)['Parameter']['Value']
except ClientError as e:
    # Handle error if unable to retrieve credentials from Parameter Store
    raise e
queue_name = "purchase_event"

params = pika.URLParameters(amqp_url)
connection = pika.BlockingConnection(params)
channel = connection.channel()

# Boto3 SES client
ses_client = boto3.client("ses", region_name=os.environ["AWS_REGION"])

@app.route("/email", methods=["POST"])
def send_email():
    data = request.get_json()
    email = data.get("email")
    message = data.get("message")

    # Send email using SES client
    response = ses_client.send_email(
        Source=os.environ["SENDER_EMAIL"],
        Destination={"ToAddresses": [email]},
        Message={"Subject": {"Data": "Purchase Confirmation"}, "Body": {"Text": {"Data": message}}},
    )

    return jsonify({"message": "Email sent successfully"}), 200

@app.route("/consume_notification_queue", methods=["POST"])
def consume_notification_queue():
    try:
        # Consume messages from the notification queue
        def callback(ch, method, properties, body):
            # Parse the message data
            notification_data = json.loads(body)

            # Perform the necessary action based on the notification type
            notification_type = notification_data.get("type")
            if notification_type == "email":
                send_email(notification_data)
            elif notification_type == "sms":
                requests.post("http://localhost:5001/api/sms", data=notification_data)

            # Acknowledge the message so it auto deletes when consumed
            ch.basic_ack(delivery_tag=method.delivery_tag)

        # Start consuming messages from the queue
        channel.basic_qos(prefetch_count=1)
        channel.basic_consume(queue="notification_queue", on_message_callback=callback)
        channel.start_consuming()

        return jsonify({"message": "Notification queue consumed successfully"})

    except Exception as e:
        return jsonify(error=str(e)), 500
