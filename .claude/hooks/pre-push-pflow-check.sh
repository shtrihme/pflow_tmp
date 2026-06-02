#!/bin/bash
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only run for git push commands
if ! echo "$COMMAND" | grep -q "git push"; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$SCRIPT_DIR/../.." && pwd)"

VALIDATE_OUT=$(node "$WORKSPACE/.pflow/mcp/pflow-mcp.cjs" tool pflow_validate --args '{}' 2>&1)
HAS_ERRORS=$(echo "$VALIDATE_OUT" | jq -r '.has_errors // false' 2>/dev/null || echo "false")

ASPECTS_OUT=$(node "$WORKSPACE/.pflow/mcp/pflow-mcp.cjs" tool pflow_aspect_v2_status --args '{}' 2>&1)
MISSING=$(echo "$ASPECTS_OUT" | jq -r '.summary.missing // 0' 2>/dev/null || echo "0")
STALE=$(echo "$ASPECTS_OUT" | jq -r '.summary.stale // 0' 2>/dev/null || echo "0")

CONTEXT=$(printf "=== pflow_validate ===\n%s\n\n=== pflow_aspect_v2_status ===\n%s" "$VALIDATE_OUT" "$ASPECTS_OUT")

if [ "$HAS_ERRORS" = "true" ]; then
  jq -n \
    --arg ctx "$CONTEXT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "pflow_validate нашёл ошибки — исправь перед пушем",
        "additionalContext": $ctx
      }
    }'
  exit 0
fi

# Allow push, but inject aspect status so agent can update stale/missing before continuing
jq -n \
  --argjson missing "$MISSING" \
  --argjson stale "$STALE" \
  --arg ctx "$CONTEXT" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow",
      "additionalContext": $ctx
    }
  }'
exit 0
