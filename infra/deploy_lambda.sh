#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME=lambda-mcp-echo
ROLE_ARN="${1:?Usage: deploy_lambda.sh <ROLE_ARN>}"

pushd lambda >/dev/null
zip -r ../lambda.zip . >/dev/null
popd >/dev/null

aws lambda create-function   --function-name "$FUNCTION_NAME"   --runtime python3.12   --handler app.handler   --zip-file fileb://lambda.zip   --role "$ROLE_ARN" >/dev/null 2>&1 || aws lambda update-function-code   --function-name "$FUNCTION_NAME"   --zip-file fileb://lambda.zip >/dev/null

aws lambda wait function-active --function-name "$FUNCTION_NAME"
aws lambda get-function --function-name "$FUNCTION_NAME" --query Configuration.FunctionArn --output text
