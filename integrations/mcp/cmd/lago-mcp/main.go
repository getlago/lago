// Command lago-mcp is a read-only MCP server exposing Lago billing data as agent
// tools over stdio. Point an MCP client (Claude Desktop, Claude Code, etc.) at it
// with LAGO_API_URL and LAGO_API_KEY set.
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/gridiron-robotics/lago/integrations/mcp"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	client := mcp.NewLagoClient(os.Getenv("LAGO_API_URL"), os.Getenv("LAGO_API_KEY"), nil)
	server := mcp.NewServer("lago-erp-readonly", "0.1.0", mcp.ReadOnlyTools(client))

	if err := server.Serve(ctx, os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "lago-mcp:", err)
		os.Exit(1)
	}
}
