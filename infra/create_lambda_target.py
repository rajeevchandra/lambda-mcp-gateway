import os, boto3

region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
ctl = boto3.client("bedrock-agentcore-control", region_name=region)

gateway_id = os.environ["GATEWAY_ID"]
lambda_arn = os.environ["LAMBDA_ARN"]
target_name = os.environ.get("TARGET_NAME", "LambdaUsingSDK")

lambda_target_config = {
    "mcp": {
        "lambda": {
            "lambdaArn": lambda_arn,
            "toolSchema": {
                "inlinePayload": [
                    {
                        "name": "get_order_tool",
                        "description": "tool to get the order",
                        "inputSchema": {
                            "type": "object",
                            "properties": {"orderId": {"type": "string"}},
                            "required": ["orderId"],
                        },
                    },
                    {
                        "name": "update_order_tool",
                        "description": "tool to update the orderId",
                        "inputSchema": {
                            "type": "object",
                            "properties": {"orderId": {"type": "string"}},
                            "required": ["orderId"],
                        },
                    },
                ]
            },
        }
    }
}

credential_config = [{"credentialProviderType": "GATEWAY_IAM_ROLE"}]

resp = ctl.create_gateway_target(
    gatewayIdentifier=gateway_id,
    name=target_name,
    description="Lambda Target using SDK",
    targetConfiguration=lambda_target_config,
    credentialProviderConfigurations=credential_config,
)
print("targetId:", resp.get("targetId", "<unknown>"))
