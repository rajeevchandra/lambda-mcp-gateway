import os, requests, json

REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")
GATEWAY_URL = os.environ["GATEWAY_URL"]

access_token = os.environ.get("ACCESS_TOKEN")
if not access_token:
    USER_POOL_ID = os.environ["USER_POOL_ID"]
    CLIENT_ID = os.environ["APP_CLIENT_ID"]
    CLIENT_SECRET = os.environ["APP_CLIENT_SECRET"]
    SCOPE = os.environ.get("SCOPE", "mcp-gateway/gateway:read mcp-gateway/gateway:write")

    TOKEN_URL = os.environ.get("TOKEN_URL", f"https://cognito-idp.{REGION}.amazonaws.com/{USER_POOL_ID}/oauth2/token")
    auth = requests.auth.HTTPBasicAuth(CLIENT_ID, CLIENT_SECRET)
    resp = requests.post(TOKEN_URL, headers={"Content-Type": "application/x-www-form-urlencoded"},
                         data={"grant_type": "client_credentials", "scope": SCOPE}, auth=auth)
    if not resp.ok:
        print("Token error:", resp.status_code, resp.text)
        resp.raise_for_status()
    access_token = resp.json()["access_token"]

print("Using access token")
headers = {"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"}

# List tools
r = requests.post(GATEWAY_URL, headers=headers, json={"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}})
print("ListTools status:", r.status_code)
try:
    print(json.dumps(r.json(), indent=2))
except Exception:
    print(r.text)

# Invoke get_order_tool
payload = {
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {"name": "LambdaUsingSDK___get_order_tool", "arguments": {"orderId": "123"}}
}
ri = requests.post(GATEWAY_URL, headers=headers, json=payload)
print("InvokeTools status:", ri.status_code)

try:
    j = ri.json()
    raw_text = j.get("result",{}).get("content",[{}])[0].get("text")
    unwrapped = json.loads(raw_text) if isinstance(raw_text, str) else raw_text
    print("Tool result:", json.dumps(unwrapped, indent=2))
except Exception:
    print(ri.text)
