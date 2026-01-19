#!/bin/bash
# FoundryDeploy - Check EC2 Instance Status
# Run this script to check if your Foundry server is running
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

# Get instance details
RESULT=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,InstanceType]' \
    --output text 2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to get instance status. Check your AWS credentials and instance ID."
    exit 1
fi

STATUS=$(echo "$RESULT" | awk '{print $1}')
PUBLIC_IP=$(echo "$RESULT" | awk '{print $2}')
INSTANCE_TYPE=$(echo "$RESULT" | awk '{print $3}')

echo ""
echo "========================================"
echo "Foundry Server Status"
echo "========================================"
echo ""
echo "Instance ID:   $INSTANCE_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Status:        $STATUS"

if [ "$STATUS" = "running" ] && [ "$PUBLIC_IP" != "None" ]; then
    echo "Public IP:     $PUBLIC_IP"
    echo ""
    echo "URL: https://$PUBLIC_IP"
    echo "SSH: ssh -i ~/.ssh/your-key.pem ubuntu@$PUBLIC_IP"
elif [ "$STATUS" = "stopped" ]; then
    echo ""
    echo "Instance is stopped. Run ./foundry-start.sh to start."
elif [ "$STATUS" = "pending" ]; then
    echo ""
    echo "Instance is starting up..."
elif [ "$STATUS" = "stopping" ]; then
    echo ""
    echo "Instance is shutting down..."
fi
echo ""
