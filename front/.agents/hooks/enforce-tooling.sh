#!/usr/bin/env bash
#
# Claude Code PreToolUse hook: enforce project tooling conventions.
# Blocks yarn, npm, npx, and vitest — directs to pnpm equivalents.
#
# Exit 0 = allow
# Exit 2 = block (stderr = reason shown to Claude)

set -euo pipefail

INPUT=$(cat)

# Extract the command from tool_input.command
if command -v jq &>/dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
  COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))")
fi

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Check if a token appears in command position (not inside a path or variable name).
# Matches after: start of string, &&, ||, ;, |, `, $(, or common prefixes like sudo/env.
check_command_position() {
  local token="$1"
  echo "$COMMAND" | grep -qE "(^|[;&|)\`(]|&&|\|\|)\s*(sudo\s+|env\s+|command\s+|xargs\s+|exec\s+|time\s+)*${token}(\s|$|[;&|)])"
}

# --- Rule 1: Block npm ---
if check_command_position "npm"; then
  echo "BLOCKED: Do not use npm. This project uses pnpm." >&2
  echo "  npm install -> pnpm install" >&2
  echo "  npm run dev -> pnpm dev" >&2
  echo "  npm test    -> pnpm test" >&2
  exit 2
fi

# --- Rule 2: Block yarn ---
if check_command_position "yarn"; then
  echo "BLOCKED: Do not use yarn. This project uses pnpm." >&2
  echo "  yarn install -> pnpm install" >&2
  echo "  yarn add foo -> pnpm add foo" >&2
  echo "  yarn dev     -> pnpm dev" >&2
  exit 2
fi

# --- Rule 3: Block npx (use pnpm dlx) ---
if check_command_position "npx"; then
  echo "BLOCKED: Do not use npx. This project uses pnpm." >&2
  echo "  npx some-tool -> pnpm dlx some-tool" >&2
  exit 2
fi

# --- Rule 4: Block vitest ---
if check_command_position "vitest"; then
  echo "BLOCKED: Do not use vitest. This project uses Jest for testing." >&2
  echo "  Use 'pnpm test' to run tests." >&2
  exit 2
fi

# Also catch vitest being installed as a package
if echo "$COMMAND" | grep -qE "(pnpm|npm|yarn|npx)\s+(add|install|i|dlx)\s+.*\bvitest\b"; then
  echo "BLOCKED: Do not install vitest. This project uses Jest." >&2
  echo "  Use 'pnpm test' to run tests." >&2
  exit 2
fi

exit 0
