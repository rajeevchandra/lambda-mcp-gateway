#!/usr/bin/env bash
set -euo pipefail

REGION=${AWS_DEFAULT_REGION:-us-east-1}
POOL_NAME=mcp-gateway-pool
RS_ID=mcp-gateway
RS_NAME=mcp-gateway-resource
CLIENT_NAME=mcp-gateway-client
SCOPES='[{"ScopeName": "gateway:read", "ScopeDescription": "Read access"}, {"ScopeName": "gateway:write", "ScopeDescription": "Write access"}]'

# Create (or reuse) pool
USER_POOL_ID=$(aws cognito-idp create-user-pool --pool-name "$POOL_NAME"   --query UserPool.Id --output text 2>/dev/null || true)
if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "None" ]; then
  USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='$POOL_NAME'].Id|[0]" --output text)
fi

# Resource server + scopes
aws cognito-idp create-resource-server   --user-pool-id "$USER_POOL_ID"   --identifier "$RS_ID"   --name "$RS_NAME"   --scopes "$SCOPES" >/dev/null 2>&1 || true

# App client (machine-to-machine)
APP_CLIENT_ID=$(aws cognito-idp create-user-pool-client   --user-pool-id "$USER_POOL_ID"   --client-name "$CLIENT_NAME"   --generate-secret   --allowed-o-auth-flows client_credentials   --allowed-o-auth-scopes "$RS_ID/gateway:read" "$RS_ID/gateway:write"   --allowed-o-auth-flows-user-pool-client   --query UserPoolClient.ClientId --output text)
APP_CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client   --user-pool-id "$USER_POOL_ID"   --client-id "$APP_CLIENT_ID"   --query "UserPoolClient.ClientSecret" --output text)

DISCOVERY_URL="https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID}/.well-known/openid-configuration"

echo "USER_POOL_ID=$USER_POOL_ID"
echo "APP_CLIENT_ID=$APP_CLIENT_ID"
echo "APP_CLIENT_SECRET=$APP_CLIENT_SECRET"
echo "COGNITO_DISCOVERY_URL=$DISCOVERY_URL"
