import json

def handler(event, context):
    # Log raw event so we can see what Gateway sends
    try:
        print("EVENT:", json.dumps(event))
    except Exception:
        print("EVENT: <unserializable>")

    # Normalize payload shape: Gateway may wrap as 'arguments' or 'input'
    data = {}
    if isinstance(event, dict):
        if isinstance(event.get("arguments"), dict):
            data = event["arguments"]
        elif isinstance(event.get("input"), dict):
            data = event["input"]
        else:
            data = event

    order_id = data.get("orderId")
    op = (data.get("op") or "get_order")

    if op == "get_order":
        return {"orderId": order_id, "status": "SHIPPED", "updatedAt": "2025-08-01T12:00:00Z"}
    if op == "update_order":
        return {"orderId": order_id, "status": "UPDATED", "updatedAt": "2025-08-02T09:00:00Z"}

    return {"error": "unknown op", "hint": "use op=get_order|update_order"}
