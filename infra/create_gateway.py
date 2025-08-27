import os, boto3

region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
client = boto3.client("bedrock-agentcore-control", region_name=region)

GW_NAME = os.environ.get("GW_NAME", "mcp-echo-gateway")
ROLE_ARN = os.environ["GW_CONTROL_ROLE_ARN"]
DISCOVERY_URL = os.environ["COGNITO_DISCOVERY_URL"]
APP_CLIENT_ID = os.environ["APP_CLIENT_ID"]

resp = client.create_gateway(
    name=GW_NAME,
    roleArn=ROLE_ARN,
    protocolType="MCP",
    authorizerType="CUSTOM_JWT",
    authorizerConfiguration={"customJWTAuthorizer": {"allowedClients": [APP_CLIENT_ID], "discoveryUrl": DISCOVERY_URL}},
    description="AgentCore Gateway with AWS Lambda target type",
)
print("gatewayId:", resp["gatewayId"])
print("gatewayUrl:", resp["gatewayUrl"])
