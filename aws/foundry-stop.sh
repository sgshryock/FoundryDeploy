#!/bin/bash
# FoundryDeploy - Stop EC2 Instance
# Run this script from your local machine after game sessions to save costs
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

echo "Stopping Foundry server..."
if ! aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1; then
    echo "Error: Failed to stop instance. Check your AWS credentials and instance ID."
    exit 1
fi

echo "Waiting for instance to stop..."
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"

echo ""
echo "========================================"
echo "Foundry server stopped."
echo "========================================"
echo ""
echo "You will not be charged for EC2 compute while stopped."
echo "(EBS storage charges still apply: ~$4/month for 50GB)"
echo ""
