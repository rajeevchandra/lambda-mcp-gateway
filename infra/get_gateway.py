import os, boto3

region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
gw_id = os.environ["GATEWAY_ID"]

client = boto3.client("bedrock-agentcore-control", region_name=region)

resp = client.get_gateway(gatewayIdentifier=gw_id)
print("Gateway ID:", resp["gatewayId"])
print("Gateway URL:", resp["gatewayUrl"])
print("Role ARN:", resp["roleArn"])
