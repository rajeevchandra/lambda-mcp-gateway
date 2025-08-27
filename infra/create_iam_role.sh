#!/usr/bin/env bash
set -euo pipefail

ROLE_NAME=lambda-mcp-echo-role

TRUST='{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}
  ]
}'

aws iam create-role   --role-name "$ROLE_NAME"   --assume-role-policy-document "$TRUST" >/dev/null 2>&1 || true

aws iam attach-role-policy   --role-name "$ROLE_NAME"   --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >/dev/null 2>&1 || true

echo "Role ARN:"
aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text
