AI_MODEL="fable"
REASONING_EFFORT="max"

USER_PROMPT="cut"

claude \
  --model "$AI_MODEL" \
  --effort "$REASONING_EFFORT" \
  --system-prompt "$(cat "./prompts/agents/streamer/system-prompt.md")" \
  "$(cat "./prompts/agents/streamer/user_prompts/$USER_PROMPT.md")"