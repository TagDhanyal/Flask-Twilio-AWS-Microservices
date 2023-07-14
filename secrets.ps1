# Set your Twilio account SID and auth token
$twilioAccountSid = ""
$twilioAuthToken = ""

# Set your MongoDB connection string
$mongodbConnectionString = "mongodb://<username>:<password>@<host>:<port>/<database>"

# Set the AWS region
$region = "us-east-2"

# Create the Parameter Store
aws ssm create-parameter --name "/twilio/account-sid" --value "$twilioAccountSid" --type SecureString --region $region
aws ssm create-parameter --name "/twilio/auth-token" --value "$twilioAuthToken" --type SecureString --region $region
aws ssm create-parameter --name "/mongodb-string" --value "$mongodbConnectionString" --type SecureString --key-id "alias/aws/ssm" --region $region