#!/bin/bash
# FoundryDeploy - Start EC2 Instance
# Run this script from your local machine before game sessions
#
# Prerequisites:
#   1. AWS CLI installed and configured (aws configure)
#   2. Set INSTANCE_ID and REGION below

INSTANCE_ID="${FOUNDRY_INSTANCE_ID:-i-xxxxxxxxxxxxxxxxx}"  # Set your instance ID
REGION="${AWS_REGION:-us-east-1}"                          # Set your region

# Validate instance ID is set
if [[ "$INSTANCE_ID" == "i-xxxxxxxxxxxxxxxxx" ]]; then
    echo "Error: Please set INSTANCE_ID in this script or export FOUNDRY_INSTANCE_ID"
    echo "Example: export FOUNDRY_INSTANCE_ID=i-0123456789abcdef0"
    exit 1
fi

echo "Starting Foundry server..."
if ! aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1; then
    echo "Error: Failed to start instance. Check your AWS credentials and instance ID."
    exit 1
fi

echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

# Get the public IP (changes on each start unless using Elastic IP)
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "========================================"
echo "Foundry server is starting!"
echo "========================================"
echo ""
echo "Public IP: $PUBLIC_IP"
echo "URL:       https://$PUBLIC_IP"
echo ""
echo "Note: Foundry takes 1-2 minutes to fully start after the instance is running."
echo ""
echo "SSH: ssh -i ~/.ssh/your-key.pem ubuntu@$PUBLIC_IP"
echo ""
