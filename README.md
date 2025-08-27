MCPify your AWS Lambda with Bedrock AgentCore Gateway

Turn an AWS Lambda function into a secure MCP tool exposed via Bedrock AgentCore Gateway. This repo includes:

Robust Lambda handler (accepts arguments/input, defaults op=get_order)

Simple client that pretty-prints Gateway results and unwraps the JSON string in MCP responses

Helper scripts to create the Gateway and add the Lambda target

End-to-end Windows CMD runbook: scripts\windows_runbook.cmd

Architecture

Inbound auth: Amazon Cognito (OAuth2 client credentials).

Gateway: AgentCore Gateway (protocol: MCP).

Outbound auth: Gateway assumes an IAM role to call Lambda.

Tools: get_order_tool, update_order_tool backed by one Lambda.

Prerequisites

Windows, Python 3.11+, AWS CLI v2, configured credentials with admin (or equivalent) in your target account.

Python libs: boto3, requests

pip install boto3 requests


Region: default is us-east-1 (override with set AWS_DEFAULT_REGION=<your-region>).

Quick start (Windows CMD)

The fastest way is to run the commands already bundled in
scripts\windows_runbook.cmd. Open it to review, then run the steps inline.

Create & deploy the Lambda

REM Create an execution role for Lambda (basic logs)
echo {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]} > trust.json
aws iam create-role --role-name lambda-mcp-echo-role --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name lambda-mcp-echo-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
for /f "delims=" %A in ('aws iam get-role --role-name lambda-mcp-echo-role --query Role.Arn --output text') do set ROLE_ARN=%A

REM Zip and deploy
python - <<PY
import zipfile, os
z=zipfile.ZipFile('lambda.zip','w',zipfile.ZIP_DEFLATED)
for f in os.listdir('lambda'):
    p=os.path.join('lambda',f)
    if os.path.isfile(p): z.write(p, arcname=f)
z.close()
PY
aws lambda create-function --function-name lambda-mcp-echo --runtime python3.12 --handler app.handler --zip-file fileb://lambda.zip --role %ROLE_ARN%
aws lambda wait function-active --function-name lambda-mcp-echo


Set up Cognito (pool, resource server, client, domain)

for /f "delims=" %A in ('aws cognito-idp create-user-pool --pool-name mcp-gateway-pool --query UserPool.Id --output text') do set USER_POOL_ID=%A
aws cognito-idp create-resource-server --user-pool-id %USER_POOL_ID% --identifier mcp-gateway --name mcp-gateway-resource --scopes ScopeName=gateway:read,ScopeDescription="Read access" ScopeName=gateway:write,ScopeDescription="Write access"
for /f "delims=" %A in ('aws cognito-idp create-user-pool-client --user-pool-id %USER_POOL_ID% --client-name mcp-gateway-client --generate-secret --allowed-o-auth-flows client_credentials --allowed-o-auth-scopes mcp-gateway/gateway:read mcp-gateway/gateway:write --allowed-o-auth-flows-user-pool-client --query UserPoolClient.ClientId --output text') do set APP_CLIENT_ID=%A
for /f "delims=" %A in ('aws cognito-idp describe-user-pool-client --user-pool-id %USER_POOL_ID% --client-id %APP_CLIENT_ID% --query "UserPoolClient.ClientSecret" --output text') do set APP_CLIENT_SECRET=%A
set COG_DOMAIN=mcp-gw-%RANDOM%
aws cognito-idp create-user-pool-domain --user-pool-id %USER_POOL_ID% --domain %COG_DOMAIN%
set TOKEN_URL=https://%COG_DOMAIN%.auth.%AWS_DEFAULT_REGION%.amazoncognito.com/oauth2/token
set COGNITO_DISCOVERY_URL=https://cognito-idp.%AWS_DEFAULT_REGION%.amazonaws.com/%USER_POOL_ID%/.well-known/openid-configuration


Create the Gateway

REM You can reuse an admin role or create a dedicated one; it must allow AgentCore control-plane actions.
set GW_CONTROL_ROLE_ARN=<YOUR_CONTROL_ROLE_ARN>

set APP_CLIENT_ID=%APP_CLIENT_ID%
python infra\create_gateway.py
REM Capture the printed values:
REM set GATEWAY_ID=...
REM set GATEWAY_URL=...


Add the Lambda target

for /f "delims=" %A in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%A
set LAMBDA_ARN=arn:aws:lambda:%AWS_DEFAULT_REGION%:%ACCOUNT_ID%:function:lambda-mcp-echo
python infra\create_lambda_target.py


Let the Gateway runtime invoke Lambda

REM Find the role the Gateway *executes as* (runtime role)
python infra\get_gateway_role.py > gw_role.txt
for /f %A in (gw_role.txt) do set GW_EXEC_ROLE_ARN=%A
for /f "tokens=2 delims=/" %A in ("%GW_EXEC_ROLE_ARN%") do set GW_EXEC_ROLE_NAME=%A

REM Attach invoke permission to that role
echo {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["lambda:InvokeFunction"],"Resource":["arn:aws:lambda:%AWS_DEFAULT_REGION%:%ACCOUNT_ID%:function:lambda-mcp-echo","arn:aws:lambda:%AWS_DEFAULT_REGION%:%ACCOUNT_ID%:function:lambda-mcp-echo:*"]}]} > gw-invoke-policy.json
aws iam put-role-policy --role-name %GW_EXEC_ROLE_NAME% --policy-name AllowInvokeLambdaMcpEcho --policy-document file://gw-invoke-policy.json

REM Ensure its trust policy allows AgentCore to assume it (principal: bedrock-agentcore.amazonaws.com)


Get a token and test

curl -sS -X POST "%TOKEN_URL%" -H "Content-Type: application/x-www-form-urlencoded" -u %APP_CLIENT_ID%:%APP_CLIENT_SECRET% -d "grant_type=client_credentials&scope=mcp-gateway/gateway:read%20mcp-gateway/gateway:write" > token.json
for /f "tokens=2 delims=:," %A in ('type token.json ^| findstr /i "access_token"') do set ACCESS_TOKEN=%~A
set ACCESS_TOKEN=%ACCESS_TOKEN:~1,-1%

REM List tools
curl -sS -X POST "%GATEWAY_URL%" -H "Content-Type: application/json" -H "Authorization: Bearer %ACCESS_TOKEN%" --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}"

REM Call tool
curl -sS -X POST "%GATEWAY_URL%" -H "Content-Type: application/json" -H "Authorization: Bearer %ACCESS_TOKEN%" --data "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"LambdaUsingSDK___get_order_tool\",\"arguments\":{\"orderId\":\"123\"}}}"


Or run the Python client:

set GATEWAY_URL=<from create_gateway.py>
set ACCESS_TOKEN=<from token.json>
python client\strands_agent_demo.py

Repository layout
lambda/
  app.py                 # robust handler (accepts 'arguments'/'input', defaults op)
  requirements.txt
client/
  strands_agent_demo.py  # lists tools, invokes, pretty-prints result
infra/
  create_gateway.py
  create_lambda_target.py
  get_gateway_role.py
scripts/
  windows_runbook.cmd    # all commands in order (Windows CMD)
README.md

Troubleshooting

400 Bad Request on token
Use the domain token endpoint:
https://<domain>.auth.<region>.amazoncognito.com/oauth2/token
Ensure client has client_credentials flow and scopes:
mcp-gateway/gateway:read mcp-gateway/gateway:write.

tools/call → isError:true and no CloudWatch logs
The Gateway isn’t invoking Lambda. Grant lambda:InvokeFunction on your function to the Gateway execution role, and make sure its trust policy includes:
"Service": "bedrock-agentcore.amazonaws.com".

Direct Lambda invoke works but Gateway still errors
Wait ~60s for IAM to propagate, retry. If still failing, re-check the exact role from infra\get_gateway_role.py and attach the invoke policy to that role.

JSON parse errors on tools/list
Send proper JSON-RPC 2.0:
{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}.

Clean up

Delete the Gateway target, then the Gateway.

Delete the Lambda function and its log group /aws/lambda/lambda-mcp-echo.

Remove IAM inline policies and roles you created.

Delete Cognito pool, client, and domain if they were created just for the test.