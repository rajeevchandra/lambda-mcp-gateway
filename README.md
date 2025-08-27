MCPify your AWS Lambda with Bedrock AgentCore Gateway

Transform AWS Lambda functions into secure MCP tools that can be discovered and invoked by agents via Bedrock AgentCore Gateway.

This project demonstrates:

✅ A robust Lambda handler (app.py) that accepts both arguments and input payloads and defaults op=get_order.

✅ A simple client that pretty-prints Gateway results and unwraps JSON strings in MCP responses.

✅ Helper scripts to create the Gateway and add the Lambda target.

✅ A full Windows CMD runbook (scripts/windows_runbook.cmd) with all commands in order.

🔎 Architecture

Inbound auth → Amazon Cognito (OAuth2 client credentials).

Gateway → AgentCore Gateway (protocol: MCP).

Outbound auth → Gateway assumes an IAM role to call Lambda.

Tools → get_order_tool and update_order_tool, both backed by a single Lambda function.

📋 Prerequisites

Windows

Python 3.11+

AWS CLI v2

AWS account with IAM admin or equivalent rights

Python libraries:

pip install boto3 requests


Default region: us-east-1 (override with set AWS_DEFAULT_REGION=<your-region>).

🚀 Quick start (Windows CMD)

The fastest way is to run:

scripts\windows_runbook.cmd



🧹 Clean up

Delete the Gateway target, then the Gateway.

Remove the Lambda function and its log group /aws/lambda/lambda-mcp-echo.

Delete IAM roles and policies you created.

Remove Cognito pool, client, and domain if only used for testing.
