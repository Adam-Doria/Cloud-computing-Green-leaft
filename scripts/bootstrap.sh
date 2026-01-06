set -e

if [ -f .env ]; then
  export $(cat .env | xargs)
fi

echo "Creating S3 bucket..."
aws s3api create-bucket --bucket greenleaf-tfstate-p2026-paris --region eu-west-3 --create-bucket-configuration LocationConstraint=eu-west-3

echo "Enabling versioning..."
aws s3api put-bucket-versioning --bucket greenleaf-tfstate-p2026-paris --versioning-configuration Status=Enabled

echo "Creating DynamoDB table..."
aws dynamodb create-table --table-name greenleaf-tf-lock --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region eu-west-3

echo "Bootstrap complete."
