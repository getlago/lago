package mcp

import (
	"context"
	"encoding/json"
	"fmt"
)

// ReadOnlyTools returns the read-only billing tools backed by the Lago client.
// Every handler reaches Lago only through LagoClient's GET-only path, so none of
// them can mutate billing state.
func ReadOnlyTools(c *LagoClient) []Tool {
	return []Tool{
		{
			Name:        "lago_get_customer",
			Description: "Fetch a customer by external_id (billing profile, currency, metadata).",
			InputSchema: objectSchema(
				map[string]any{"external_id": stringProp("The customer's external_id")},
				"external_id",
			),
			Handler: func(ctx context.Context, args map[string]any) (string, error) {
				id, err := requireString(args, "external_id")
				if err != nil {
					return "", err
				}
				return asText(c.GetCustomer(ctx, id))
			},
		},
		{
			Name:        "lago_customer_current_usage",
			Description: "Current (uninvoiced) usage and projected cost for a customer's subscription.",
			InputSchema: objectSchema(map[string]any{
				"external_customer_id":     stringProp("The customer's external_id"),
				"external_subscription_id": stringProp("The subscription's external_id"),
			}, "external_customer_id", "external_subscription_id"),
			Handler: func(ctx context.Context, args map[string]any) (string, error) {
				cust, err := requireString(args, "external_customer_id")
				if err != nil {
					return "", err
				}
				sub, err := requireString(args, "external_subscription_id")
				if err != nil {
					return "", err
				}
				return asText(c.CurrentUsage(ctx, cust, sub))
			},
		},
		{
			Name:        "lago_list_invoices",
			Description: "List invoices, optionally filtered to one customer by external_customer_id.",
			InputSchema: objectSchema(
				map[string]any{"external_customer_id": stringProp("Optional customer external_id filter")},
			),
			Handler: func(ctx context.Context, args map[string]any) (string, error) {
				cust, _ := args["external_customer_id"].(string)
				return asText(c.ListInvoices(ctx, cust))
			},
		},
		{
			Name:        "lago_get_invoice",
			Description: "Fetch a single invoice by its lago_id (UUID).",
			InputSchema: objectSchema(
				map[string]any{"lago_id": stringProp("The invoice's lago_id (UUID)")},
				"lago_id",
			),
			Handler: func(ctx context.Context, args map[string]any) (string, error) {
				id, err := requireString(args, "lago_id")
				if err != nil {
					return "", err
				}
				return asText(c.GetInvoice(ctx, id))
			},
		},
		{
			Name:        "lago_list_subscriptions",
			Description: "List subscriptions, optionally filtered to one customer by external_customer_id.",
			InputSchema: objectSchema(
				map[string]any{"external_customer_id": stringProp("Optional customer external_id filter")},
			),
			Handler: func(ctx context.Context, args map[string]any) (string, error) {
				cust, _ := args["external_customer_id"].(string)
				return asText(c.ListSubscriptions(ctx, cust))
			},
		},
		{
			Name:        "lago_list_wallets",
			Description: "List prepaid credit wallets and balances for a customer.",
			InputSchema: objectSchema(
				map[string]any{"external_customer_id": stringProp("The customer's external_id")},
				"external_customer_id",
			),
			Handler: func(ctx context.Context, args map[string]any) (string, error) {
				cust, err := requireString(args, "external_customer_id")
				if err != nil {
					return "", err
				}
				return asText(c.ListWallets(ctx, cust))
			},
		},
	}
}

func stringProp(desc string) map[string]any {
	return map[string]any{"type": "string", "description": desc}
}

func objectSchema(props map[string]any, required ...string) map[string]any {
	m := map[string]any{"type": "object", "properties": props}
	if len(required) > 0 {
		m["required"] = required
	}
	return m
}

func requireString(args map[string]any, key string) (string, error) {
	v, ok := args[key]
	if !ok {
		return "", fmt.Errorf("missing required argument %q", key)
	}
	s, ok := v.(string)
	if !ok || s == "" {
		return "", fmt.Errorf("argument %q must be a non-empty string", key)
	}
	return s, nil
}

func asText(raw json.RawMessage, err error) (string, error) {
	if err != nil {
		return "", err
	}
	return string(raw), nil
}
