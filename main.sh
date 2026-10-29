#!/usr/bin/env bash
set -euo pipefail

USER_PROMPT="cut"

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_PROMPT_CONTENT="$(cat "$REPOSITORY_ROOT/prompts/agents/streamer/system-prompt.md")"
USER_PROMPT_CONTENT="$(cat "$REPOSITORY_ROOT/prompts/agents/streamer/user_prompts/$USER_PROMPT.md")"

exec codex \
  --cd "$REPOSITORY_ROOT" \
  --search \
  --sandbox workspace-write \
  --config "developer_instructions=$SYSTEM_PROMPT_CONTENT" \
  "$USER_PROMPT_CONTENT"
