@echo off
REM Windows Command Prompt Runbook for lambda-mcp-gateway (updated)

REM --- Prereqs ---
REM pip install boto3 requests
REM set AWS_DEFAULT_REGION=us-east-1

REM 1) Create Lambda execution role (once)
echo {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]} > trust.json
aws iam create-role --role-name lambda-mcp-echo-role --assume-role-policy-document file://trust.json 1>NUL 2>NUL
aws iam attach-role-policy --role-name lambda-mcp-echo-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 1>NUL 2>NUL
for /f "delims=" %%A in ('aws iam get-role --role-name lambda-mcp-echo-role --query Role.Arn --output text') do set ROLE_ARN=%%A

REM 2) Deploy Lambda
python - <<PY
import zipfile, os
z=zipfile.ZipFile('lambda.zip','w',zipfile.ZIP_DEFLATED)
for f in os.listdir('lambda'):
    p=os.path.join('lambda',f)
    if os.path.isfile(p): z.write(p, arcname=f)
z.close()
PY
aws lambda create-function --function-name lambda-mcp-echo --runtime python3.12 --handler app.handler --zip-file fileb://lambda.zip --role %ROLE_ARN% 1>NUL 2>NUL
aws lambda update-function-code --function-name lambda-mcp-echo --zip-file fileb://lambda.zip
aws lambda wait function-active --function-name lambda-mcp-echo

REM 3) Cognito: user pool, resource server, client, domain
for /f "delims=" %%A in ('aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='mcp-gateway-pool'].Id|[0]" --output text') do set USER_POOL_ID=%%A
if "%USER_POOL_ID%"=="None" (
  for /f "delims=" %%A in ('aws cognito-idp create-user-pool --pool-name mcp-gateway-pool --query UserPool.Id --output text') do set USER_POOL_ID=%%A
)
aws cognito-idp create-resource-server --user-pool-id %USER_POOL_ID% --identifier mcp-gateway --name mcp-gateway-resource --scopes ScopeName=gateway:read,ScopeDescription="Read access" ScopeName=gateway:write,ScopeDescription="Write access" 1>NUL 2>NUL
for /f "delims=" %%A in ('aws cognito-idp create-user-pool-client --user-pool-id %USER_POOL_ID% --client-name mcp-gateway-client --generate-secret --allowed-o-auth-flows client_credentials --allowed-o-auth-scopes mcp-gateway/gateway:read mcp-gateway/gateway:write --allowed-o-auth-flows-user-pool-client --query UserPoolClient.ClientId --output text') do set APP_CLIENT_ID=%%A
for /f "delims=" %%A in ('aws cognito-idp describe-user-pool-client --user-pool-id %USER_POOL_ID% --client-id %APP_CLIENT_ID% --query "UserPoolClient.ClientSecret" --output text') do set APP_CLIENT_SECRET=%%A
for /f "delims=" %%A in ('aws cognito-idp describe-user-pool --user-pool-id %USER_POOL_ID% --query "UserPool.Domain" --output text') do set COG_DOMAIN=%%A
if "%COG_DOMAIN%"=="None" (
  set COG_DOMAIN=mcp-gw-%RANDOM%
  aws cognito-idp create-user-pool-domain --user-pool-id %USER_POOL_ID% --domain %COG_DOMAIN%
)
set TOKEN_URL=https://%COG_DOMAIN%.auth.%AWS_DEFAULT_REGION%.amazoncognito.com/oauth2/token

REM 4) Create Gateway
set GW_CONTROL_ROLE_ARN=<YOUR_CONTROL_OR_EXEC_ROLE_ARN_WITH_AGENTCORE_PERMS>
set COGNITO_DISCOVERY_URL=https://cognito-idp.%AWS_DEFAULT_REGION%.amazonaws.com/%USER_POOL_ID%/.well-known/openid-configuration
set APP_CLIENT_ID=%APP_CLIENT_ID%
python infra\create_gateway.py
REM Manually set these from the printed output:
REM set GATEWAY_ID=...
REM set GATEWAY_URL=...

REM 5) Add Lambda as target
REM set GATEWAY_ID=...
REM set LAMBDA_ARN=arn:aws:lambda:%AWS_DEFAULT_REGION%:%ACCOUNT_ID%:function:lambda-mcp-echo
python infra\create_lambda_target.py

REM 6) Grant Gateway execution role permission to invoke Lambda
python infra\get_gateway_role.py > gw_role.txt
for /f %%A in (gw_role.txt) do set GW_EXEC_ROLE_ARN=%%A
for /f "tokens=2 delims=/" %%A in ("%GW_EXEC_ROLE_ARN%") do set GW_EXEC_ROLE_NAME=%%A
for /f "delims=" %%A in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%A
echo {"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["lambda:InvokeFunction"],"Resource":["arn:aws:lambda:%AWS_DEFAULT_REGION%:%ACCOUNT_ID%:function:lambda-mcp-echo","arn:aws:lambda:%AWS_DEFAULT_REGION%:%ACCOUNT_ID%:function:lambda-mcp-echo:*"]}]} > gw-invoke-policy.json
aws iam put-role-policy --role-name %GW_EXEC_ROLE_NAME% --policy-name AllowInvokeLambdaMcpEcho --policy-document file://gw-invoke-policy.json

REM 7) Get a token and call Gateway
curl -sS -X POST "%TOKEN_URL%" -H "Content-Type: application/x-www-form-urlencoded" -u %APP_CLIENT_ID%:%APP_CLIENT_SECRET% -d "grant_type=client_credentials&scope=mcp-gateway/gateway:read%20mcp-gateway/gateway:write" > token.json
for /f "tokens=2 delims=:," %%A in ('type token.json ^| findstr /i "access_token"') do set ACCESS_TOKEN=%%~A
set ACCESS_TOKEN=%ACCESS_TOKEN:~1,-1%

curl -sS -X POST "%GATEWAY_URL%" -H "Content-Type: application/json" -H "Authorization: Bearer %ACCESS_TOKEN%" --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}"
curl -sS -X POST "%GATEWAY_URL%" -H "Content-Type: application/json" -H "Authorization: Bearer %ACCESS_TOKEN%" --data "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"LambdaUsingSDK___get_order_tool\",\"arguments\":{\"orderId\":\"123\"}}}"
