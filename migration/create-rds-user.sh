#!/bin/bash

# Create AWS IAM User with RDS Permissions
# Run this with an AWS user that has IAM permissions

USER_NAME="rds-admin-user"
POLICY_NAME="RequestMarketplaceRDSPolicy"

echo "🔐 Creating AWS IAM user with RDS permissions..."

# Create IAM user
aws iam create-user --user-name $USER_NAME

# Create access key
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name $USER_NAME)
ACCESS_KEY_ID=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo $ACCESS_KEY_OUTPUT | jq -r '.AccessKey.SecretAccessKey')

# Create custom policy for RDS operations
cat > rds-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:CreateSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:DescribeAvailabilityZones"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Create policy
aws iam create-policy --policy-name $POLICY_NAME --policy-document file://rds-policy.json

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach policy to user
aws iam attach-user-policy --user-name $USER_NAME --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

echo "✅ User created successfully!"
echo "📋 Credentials:"
echo "Access Key ID: $ACCESS_KEY_ID"
echo "Secret Access Key: $SECRET_ACCESS_KEY"
echo ""
echo "🔧 To configure AWS CLI with new user:"
echo "aws configure --profile rds-admin"
echo "Then enter the above credentials"
echo ""
echo "🚀 To use this profile:"
echo "export AWS_PROFILE=rds-admin"
echo "Then run the RDS setup script"

# Cleanup
rm rds-policy.json
