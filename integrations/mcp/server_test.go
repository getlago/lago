package mcp

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"testing"
)

// runRPC feeds newline-delimited JSON-RPC requests through the server and parses
// the response lines back out.
func runRPC(t *testing.T, s *Server, requests ...string) []map[string]any {
	t.Helper()
	in := strings.NewReader(strings.Join(requests, "\n") + "\n")
	var out bytes.Buffer
	if err := s.Serve(context.Background(), in, &out); err != nil {
		t.Fatalf("Serve: %v", err)
	}
	var resps []map[string]any
	for _, line := range strings.Split(strings.TrimSpace(out.String()), "\n") {
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("bad response line %q: %v", line, err)
		}
		resps = append(resps, m)
	}
	return resps
}

func testServer() *Server {
	return NewServer("test", "0.0.1", []Tool{{
		Name:        "echo",
		Description: "echo back text",
		InputSchema: objectSchema(map[string]any{"text": stringProp("text to echo")}, "text"),
		Handler: func(_ context.Context, args map[string]any) (string, error) {
			s, _ := args["text"].(string)
			if s == "" {
				return "", fmt.Errorf("text required")
			}
			return "echo: " + s, nil
		},
	}})
}

func TestServer_InitializeAndToolsList(t *testing.T) {
	resps := runRPC(t, testServer(),
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}`,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`, // notification -> no response
		`{"jsonrpc":"2.0","id":2,"method":"tools/list"}`,
	)
	if len(resps) != 2 {
		t.Fatalf("got %d responses, want 2 (notification produces none)", len(resps))
	}
	result, _ := resps[0]["result"].(map[string]any)
	if result["protocolVersion"] != protocolVersion {
		t.Fatalf("protocolVersion = %v, want %v", result["protocolVersion"], protocolVersion)
	}
	tl, _ := resps[1]["result"].(map[string]any)
	tools, _ := tl["tools"].([]any)
	if len(tools) != 1 {
		t.Fatalf("tools length = %d, want 1", len(tools))
	}
	first, _ := tools[0].(map[string]any)
	if first["name"] != "echo" || first["inputSchema"] == nil {
		t.Fatalf("tool entry malformed: %v", first)
	}
}

func TestServer_ToolsCallSuccessAndUnknownTool(t *testing.T) {
	resps := runRPC(t, testServer(),
		`{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"echo","arguments":{"text":"hi"}}}`,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"nope","arguments":{}}}`,
	)
	if len(resps) != 2 {
		t.Fatalf("got %d responses, want 2", len(resps))
	}
	r0, _ := resps[0]["result"].(map[string]any)
	content, _ := r0["content"].([]any)
	first, _ := content[0].(map[string]any)
	if first["text"] != "echo: hi" {
		t.Fatalf("echo text = %v, want 'echo: hi'", first["text"])
	}
	r1, _ := resps[1]["result"].(map[string]any)
	if r1["isError"] != true {
		t.Fatalf("unknown tool should return isError result; got %v", resps[1])
	}
}

func TestServer_UnknownMethodIsJSONRPCError(t *testing.T) {
	resps := runRPC(t, testServer(), `{"jsonrpc":"2.0","id":1,"method":"bogus"}`)
	if len(resps) != 1 {
		t.Fatalf("got %d responses, want 1", len(resps))
	}
	if _, ok := resps[0]["error"]; !ok {
		t.Fatalf("expected JSON-RPC error for unknown method; got %v", resps[0])
	}
}
