import boto3
import botocore
from botocore.exceptions import NoCredentialsError
from flask import Flask, render_template, request
from flask_cors import CORS
from twilio.twiml.messaging_response import MessagingResponse
from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse

app = Flask(__name__)
cors = CORS(app)

# Retrieve Twilio secrets from AWS Systems Manager Parameter Store
session = boto3.Session()
ssm_client = session.client('ssm')

try:
    # Replace '/twilio/account-sid' and '/twilio/auth-token' with your Parameter Store paths
    account_sid = ssm_client.get_parameter(Name='/twilio/account-sid', WithDecryption=True)['Parameter']['Value']
    auth_token = ssm_client.get_parameter(Name='/twilio/auth-token', WithDecryption=True)['Parameter']['Value']
except NoCredentialsError as e:
    # Handle error if unable to retrieve credentials from Parameter Store
    raise e

client = Client(account_sid, auth_token)
s3 = boto3.client('s3')
bucket_name = 'purchase4ormdhanyalproj'

my_number = "+15735273578" # its a voip number/fake number i used to test

@app.route("/api/")
def purchase_form():
    try:
        response = s3.get_object(Bucket=bucket_name, Key='index.html')
        content = response['Body'].read().decode('utf-8')

        with open('templates/index.html', 'w') as file:
            file.write(content)

        return render_template("index.html")

    except botocore.exceptions.ClientError as e:
        # Handle error if the S3 object retrieval fails
        return f"Error retrieving form: {str(e)}"

@app.route("/api/sms", methods=["POST"])
def sms():
    try:
        data = request.json
        name = data.get('name')
        product = data.get('product')
        cust_number = data.get('phone')
        body = f"Hi {name}, your order for {product} has been successfully placed"

        message = client.messages.create(
            to=cust_number,
            from_=my_number,  # Replace with your Twilio phone number
            body=body
        )

        return str(message.sid)

    except Exception as e:
        # Handle error if the SMS sending fails
        return f"Error sending SMS: {str(e)}"

@app.route("/api/call_customer", methods=["POST"])
def outbound_call():
    try:
        data = request.json
        name = data.get('name')
        product = data.get('product')
        cust_number = data.get('phone')

        call = client.calls.create(
            record=True,
            url='http://demo.twilio.com/docs/classic.mp3',  # AI voice response URL
            to=cust_number,
            from_=my_number  # Replace with your Twilio phone number
        )

        return str(call.sid)

    except Exception as e:
        # Handle error if the outbound call fails
        return f"Error making outbound call: {str(e)}"

@app.route("/answer_call", methods=["GET"])
def answer_call():
    try:
        vr = VoiceResponse()
        vr.say("Thanks for calling Tag INC. An agent will get back to you shortly.")
        vr.play('https://demo.twilio.com/docs/classic.mp3')

        return str(vr)

    except Exception as e:
        # Handle error if answering the call fails
        return f"Error answering the call: {str(e)}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)