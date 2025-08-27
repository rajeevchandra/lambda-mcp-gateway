import os, json, boto3, datetime

def to_jsonable(obj):
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    if isinstance(obj, bytes):
        return obj.decode("utf-8", errors="ignore")
    if isinstance(obj, set):
        return list(obj)
    return str(obj)

region = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
gw_id = os.environ["GATEWAY_ID"]

c = boto3.client("bedrock-agentcore-control", region_name=region)

print(f"Gateway: {gw_id}\n")

lst = c.list_gateway_targets(gatewayIdentifier=gw_id)
print("Targets (summary):")
print(json.dumps(lst, default=to_jsonable, indent=2))

items = lst.get("items") or lst.get("targets") or []
for t in items:
    name = t.get("name") or t.get("targetName")
    tid = t.get("id") or t.get("targetId")
    print(f"\n--- Target: {name}  (id: {tid})")
    try:
        full = c.get_gateway_target(
            gatewayIdentifier=gw_id,
            targetId=tid
        )
        creds = full.get("credentialProviderConfigurations") or full.get("credentials") or []
        print("credentialProviderConfigurations:")
        print(json.dumps(creds, default=to_jsonable, indent=2))

        cfg = full.get("targetConfiguration") or {}
        truncated = {k: cfg.get(k) for k in ["mcp", "lambda", "type"] if k in cfg}
        print("targetConfiguration (truncated):")
        print(json.dumps(truncated, default=to_jsonable, indent=2))

        if "roleArn" in full:
            print("roleArn:", full["roleArn"])

        if isinstance(creds, list):
            for entry in creds:
                for k, v in entry.items():
                    if "role" in k.lower() or "arn" in k.lower():
                        print(f"{k}: {v}")
    except Exception as e:
        print("get_gateway_target failed:", e)
