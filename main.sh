#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIRECTORY="$REPOSITORY_ROOT/prompts/agents/streamer/user_prompts"

usage() {
  cat <<'EOF'
Usage: ./main.sh [PROMPT]
       ./main.sh --list
       ./main.sh --help

With no arguments, use Up/Down arrows to choose a prompt and Enter to launch it.
Press Esc or q to cancel.
PROMPT is a filename from prompts/agents/streamer/user_prompts;
the .md extension is optional for Markdown files.

Options:
  -l, --list  List available prompt files.
  -h, --help  Show this help.

Examples:
  ./main.sh
  ./main.sh live
  ./main.sh cut.md
EOF
}

if (( $# > 1 )); then
  printf 'Error: expected at most one argument.\n' >&2
  usage >&2
  exit 1
fi

case "${1-}" in
  -h|--help)
    usage
    exit 0
    ;;
  -l|--list) ;;
  -*)
    printf 'Error: unknown option: %s\n' "$1" >&2
    usage >&2
    exit 1
    ;;
esac

if [[ ! -d "$PROMPTS_DIRECTORY" ]]; then
  printf 'Error: prompt directory not found: %s\n' "$PROMPTS_DIRECTORY" >&2
  exit 1
fi

shopt -s nullglob
PROMPT_FILES=()
for file in "$PROMPTS_DIRECTORY"/*; do
  [[ -f "$file" ]] || continue
  PROMPT_FILES+=("${file##*/}")
done

if (( ${#PROMPT_FILES[@]} == 0 )); then
  printf 'Error: no prompt files found in %s\n' "$PROMPTS_DIRECTORY" >&2
  exit 1
fi

USER_PROMPT=""
case "${1-}" in
  -l|--list)
    printf '%s\n' "${PROMPT_FILES[@]}"
    exit 0
    ;;
esac

if (( $# == 0 )); then
  if [[ ! -t 0 || ! -t 2 ]]; then
    printf 'Error: the arrow-key menu requires a terminal. Pass a prompt name or use --list.\n' >&2
    exit 1
  fi

  TERMINAL_SETTINGS="$(stty -g)"
  restore_terminal() {
    stty "$TERMINAL_SETTINGS" || true
    printf '\033[0m\033[?25h\033[?1049l' >&2
  }
  trap restore_terminal EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  trap 'exit 148' TSTP

  stty -echo -icanon min 1 time 0 susp undef
  printf '\033[?1049h\033[?25l' >&2
  SELECTED=0

  while true; do
    read -r MENU_ROWS MENU_COLUMNS < <(stty size)
    (( MENU_ROWS > 4 )) || MENU_ROWS=24
    (( MENU_COLUMNS > 6 )) || MENU_COLUMNS=80
    VISIBLE_COUNT=$((MENU_ROWS - 4))
    FIRST_VISIBLE=$((SELECTED / VISIBLE_COUNT * VISIBLE_COUNT))

    HEADER='Choose a streamer prompt:'
    printf '\033[H\033[2J\033[1;36m%s\033[0m\n\n' "${HEADER:0:MENU_COLUMNS-1}" >&2
    for ((index = FIRST_VISIBLE; index < ${#PROMPT_FILES[@]} && index < FIRST_VISIBLE + VISIBLE_COUNT; index++)); do
      LABEL="${PROMPT_FILES[index]:0:MENU_COLUMNS-6}"
      if (( index == SELECTED )); then
        printf '\033[1;97;44m > %s \033[0m\n' "$LABEL" >&2
      else
        printf '   %s\n' "$LABEL" >&2
      fi
    done
    FOOTER="Up/Down: move | Enter: select | Esc/q: cancel ($((SELECTED + 1))/${#PROMPT_FILES[@]})"
    printf '\n\033[33m%s\033[0m' "${FOOTER:0:MENU_COLUMNS-1}" >&2

    if ! IFS= read -r -n 1 KEY; then
      exit 1
    fi
    case "$KEY" in
      ''|$'\r')
        USER_PROMPT="${PROMPT_FILES[SELECTED]}"
        break
        ;;
      q|Q|$'\004') exit 130 ;;
      $'\032') exit 148 ;;
      $'\033')
        if ! IFS= read -r -n 1 -t 0.2 PREFIX; then
          exit 130
        fi
        if [[ "$PREFIX" == '[' || "$PREFIX" == 'O' ]]; then
          if IFS= read -r -n 1 -t 0.2 DIRECTION; then
            case "$DIRECTION" in
              A) SELECTED=$(((SELECTED + ${#PROMPT_FILES[@]} - 1) % ${#PROMPT_FILES[@]})) ;;
              B) SELECTED=$(((SELECTED + 1) % ${#PROMPT_FILES[@]})) ;;
            esac
          fi
        fi
        ;;
    esac
  done

  restore_terminal
  trap - EXIT INT TERM HUP TSTP
else
  for file in "${PROMPT_FILES[@]}"; do
    if [[ "$file" == "$1" ]]; then
      USER_PROMPT="$file"
      break
    fi
  done
  if [[ -z "$USER_PROMPT" ]]; then
    for file in "${PROMPT_FILES[@]}"; do
      if [[ "$file" == "$1.md" ]]; then
        USER_PROMPT="$file"
        break
      fi
    done
  fi
  if [[ -z "$USER_PROMPT" ]]; then
    printf 'Error: unknown prompt: %s\nUse --list to see available prompts.\n' "$1" >&2
    exit 1
  fi
fi

SYSTEM_PROMPT_CONTENT="$(cat "$REPOSITORY_ROOT/prompts/agents/streamer/system-prompt.md")"
USER_PROMPT_CONTENT="$(cat "$PROMPTS_DIRECTORY/$USER_PROMPT")"

exec codex \
  --cd "$REPOSITORY_ROOT" \
  --search \
  --sandbox workspace-write \
  --config "developer_instructions=$SYSTEM_PROMPT_CONTENT" \
  "$USER_PROMPT_CONTENT"
