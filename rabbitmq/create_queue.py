import boto3, pika
from botocore.exceptions import ClientError

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
channel.queue_declare(queue=queue_name, passive=False, durable=True)
