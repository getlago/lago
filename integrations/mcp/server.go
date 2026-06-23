package mcp

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"io"
)

// protocolVersion is the MCP revision this server speaks.
const protocolVersion = "2024-11-05"

// --- JSON-RPC 2.0 wire types -------------------------------------------------

type rpcRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// Tool is a single read-only MCP tool.
type Tool struct {
	Name        string
	Description string
	InputSchema map[string]any
	Handler     func(ctx context.Context, args map[string]any) (string, error)
}

// Server is a minimal MCP server (initialize / tools/list / tools/call / ping)
// over the stdio transport (newline-delimited JSON-RPC).
type Server struct {
	name    string
	version string
	tools   map[string]Tool
	order   []string
}

// NewServer registers the given tools (order preserved for tools/list).
func NewServer(name, version string, tools []Tool) *Server {
	s := &Server{name: name, version: version, tools: make(map[string]Tool, len(tools))}
	for _, t := range tools {
		if _, dup := s.tools[t.Name]; dup {
			continue
		}
		s.tools[t.Name] = t
		s.order = append(s.order, t.Name)
	}
	return s
}

// Serve reads newline-delimited JSON-RPC requests from r and writes responses to
// w until r reaches EOF or ctx is cancelled. Notifications get no response.
func (s *Server) Serve(ctx context.Context, r io.Reader, w io.Writer) error {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)
	enc := json.NewEncoder(w)

	for sc.Scan() {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		line := bytes.TrimSpace(sc.Bytes())
		if len(line) == 0 {
			continue
		}
		var req rpcRequest
		if err := json.Unmarshal(line, &req); err != nil {
			_ = enc.Encode(errorResponse(nil, -32700, "parse error"))
			continue
		}
		resp, isNotification := s.handle(ctx, &req)
		if isNotification {
			continue
		}
		if err := enc.Encode(resp); err != nil {
			return err
		}
	}
	return sc.Err()
}

func (s *Server) handle(ctx context.Context, req *rpcRequest) (rpcResponse, bool) {
	switch req.Method {
	case "initialize":
		return s.ok(req.ID, map[string]any{
			"protocolVersion": protocolVersion,
			"capabilities":    map[string]any{"tools": map[string]any{}},
			"serverInfo":      map[string]any{"name": s.name, "version": s.version},
		}), false
	case "notifications/initialized", "notifications/cancelled":
		return rpcResponse{}, true // notifications carry no response
	case "ping":
		return s.ok(req.ID, map[string]any{}), false
	case "tools/list":
		return s.ok(req.ID, map[string]any{"tools": s.listTools()}), false
	case "tools/call":
		return s.callTool(ctx, req), false
	default:
		return errorResponse(req.ID, -32601, "method not found: "+req.Method), false
	}
}

func (s *Server) listTools() []map[string]any {
	out := make([]map[string]any, 0, len(s.order))
	for _, name := range s.order {
		t := s.tools[name]
		schema := t.InputSchema
		if schema == nil {
			schema = map[string]any{"type": "object", "properties": map[string]any{}}
		}
		out = append(out, map[string]any{
			"name":        t.Name,
			"description": t.Description,
			"inputSchema": schema,
		})
	}
	return out
}

func (s *Server) callTool(ctx context.Context, req *rpcRequest) rpcResponse {
	var p struct {
		Name      string         `json:"name"`
		Arguments map[string]any `json:"arguments"`
	}
	if err := json.Unmarshal(req.Params, &p); err != nil {
		return errorResponse(req.ID, -32602, "invalid params")
	}
	t, ok := s.tools[p.Name]
	if !ok {
		return s.toolError(req.ID, "unknown tool: "+p.Name)
	}
	text, err := t.Handler(ctx, p.Arguments)
	if err != nil {
		return s.toolError(req.ID, err.Error())
	}
	return s.ok(req.ID, map[string]any{
		"content": []map[string]any{{"type": "text", "text": text}},
	})
}

// toolError reports a tool failure as a RESULT with isError=true (MCP surfaces
// tool errors to the model this way, distinct from a JSON-RPC protocol error).
func (s *Server) toolError(id json.RawMessage, msg string) rpcResponse {
	return s.ok(id, map[string]any{
		"content": []map[string]any{{"type": "text", "text": msg}},
		"isError": true,
	})
}

func (s *Server) ok(id json.RawMessage, result any) rpcResponse {
	return rpcResponse{JSONRPC: "2.0", ID: id, Result: result}
}

func errorResponse(id json.RawMessage, code int, msg string) rpcResponse {
	return rpcResponse{JSONRPC: "2.0", ID: id, Error: &rpcError{Code: code, Message: msg}}
}
