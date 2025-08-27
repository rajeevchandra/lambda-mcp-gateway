import os, boto3
region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
gw_id  = os.environ["GATEWAY_ID"]
c = boto3.client("bedrock-agentcore-control", region_name=region)
resp = c.get_gateway(gatewayIdentifier=gw_id)
print(resp["roleArn"])
