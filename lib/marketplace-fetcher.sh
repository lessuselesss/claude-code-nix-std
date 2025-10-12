#!/usr/bin/env bash
# Marketplace plugin fetcher
# Fetches commands and agents from GitHub marketplace repositories

set -euo pipefail

fetch_plugin_files() {
  local MARKETPLACE_URL=$1
  local PLUGIN_SOURCE=$2
  local CACHE_DIR=$3

  # Convert to GitHub API URL to list files
  local REPO_PATH="''${MARKETPLACE_URL#https://github.com/}"
  local API_URL="https://api.github.com/repos/$REPO_PATH/contents/$PLUGIN_SOURCE"

  # Fetch commands
  local COMMANDS_API="$API_URL/commands"
  local COMMANDS_JSON=$(curl -sSfL "$COMMANDS_API" 2>/dev/null || echo "[]")

  if [[ "$COMMANDS_JSON" != "[]" ]]; then
    echo "$COMMANDS_JSON" | jq -r '.[].download_url' | while read -r DOWNLOAD_URL; do
      local FILENAME=$(basename "$DOWNLOAD_URL")
      local COMMAND_NAME="''${FILENAME%.md}"
      local OUTPUT_FILE="$CACHE_DIR/commands/$FILENAME"

      if curl -sSfL "$DOWNLOAD_URL" -o "$OUTPUT_FILE" 2>&1; then
        echo "  ✓ Command: /$COMMAND_NAME"
      fi
    done
  fi

  # Fetch agents
  local AGENTS_API="$API_URL/agents"
  local AGENTS_JSON=$(curl -sSfL "$AGENTS_API" 2>/dev/null || echo "[]")

  if [[ "$AGENTS_JSON" != "[]" ]]; then
    echo "$AGENTS_JSON" | jq -r '.[].download_url' | while read -r DOWNLOAD_URL; do
      local FILENAME=$(basename "$DOWNLOAD_URL")
      local AGENT_NAME="''${FILENAME%.md}"
      local OUTPUT_FILE="$CACHE_DIR/agents/$FILENAME"

      if curl -sSfL "$DOWNLOAD_URL" -o "$OUTPUT_FILE" 2>&1; then
        echo "  ✓ Agent: $AGENT_NAME"
      fi
    done
  fi
}

# Find matching command (exact or fuzzy)
find_command() {
  local CACHE_DIR=$1
  local COMMAND_NAME=$2
  local FUZZY=$3

  # Try exact match first
  local EXACT_MATCH="$CACHE_DIR/commands/${COMMAND_NAME}.md"
  if [[ -f "$EXACT_MATCH" ]]; then
    echo "$EXACT_MATCH"
    return 0
  fi

  # If fuzzy mode, find similar commands
  if [[ "$FUZZY" == "true" ]]; then
    local BEST_MATCH=""
    local BEST_SCORE=999

    for CMD_FILE in "$CACHE_DIR"/commands/*.md; do
      if [[ ! -f "$CMD_FILE" ]]; then continue; fi

      local CMD=$(basename "$CMD_FILE" .md)
      local SCORE=$(levenshtein_distance "$COMMAND_NAME" "$CMD")

      if [[ $SCORE -lt $BEST_SCORE ]]; then
        BEST_SCORE=$SCORE
        BEST_MATCH="$CMD_FILE"
      fi
    done

    if [[ -n "$BEST_MATCH" ]] && [[ $BEST_SCORE -le 3 ]]; then
      echo "$BEST_MATCH"
      return 0
    fi
  fi

  return 1
}

# Simple Levenshtein distance calculation
levenshtein_distance() {
  local s1=$1
  local s2=$2

  # Simple character difference count (approximation)
  local len1=''${#s1}
  local len2=''${#s2}
  local diff=$((len1 > len2 ? len1 - len2 : len2 - len1))

  # Count mismatched characters
  local min_len=$((len1 < len2 ? len1 : len2))
  for ((i=0; i<min_len; i++)); do
    if [[ "''${s1:i:1}" != "''${s2:i:1}" ]]; then
      ((diff++))
    fi
  done

  echo $diff
}

# Find matching agent (exact or fuzzy)
find_agent() {
  local CACHE_DIR=$1
  local AGENT_NAME=$2
  local FUZZY=$3

  # Try exact match first
  local EXACT_MATCH="$CACHE_DIR/agents/${AGENT_NAME}.md"
  if [[ -f "$EXACT_MATCH" ]]; then
    echo "$EXACT_MATCH"
    return 0
  fi

  # If fuzzy mode, find similar agents
  if [[ "$FUZZY" == "true" ]]; then
    local BEST_MATCH=""
    local BEST_SCORE=999

    for AGENT_FILE in "$CACHE_DIR"/agents/*.md; do
      if [[ ! -f "$AGENT_FILE" ]]; then continue; fi

      local AGENT=$(basename "$AGENT_FILE" .md)
      local SCORE=$(levenshtein_distance "$AGENT_NAME" "$AGENT")

      if [[ $SCORE -lt $BEST_SCORE ]]; then
        BEST_SCORE=$SCORE
        BEST_MATCH="$AGENT_FILE"
      fi
    done

    if [[ -n "$BEST_MATCH" ]] && [[ $BEST_SCORE -le 5 ]]; then
      echo "$BEST_MATCH"
      return 0
    fi
  fi

  return 1
}

# List available commands
list_commands() {
  local CACHE_DIR=$1

  if [[ -d "$CACHE_DIR/commands" ]]; then
    for CMD_FILE in "$CACHE_DIR"/commands/*.md; do
      if [[ -f "$CMD_FILE" ]]; then
        basename "$CMD_FILE" .md
      fi
    done
  fi
}

# List available agents
list_agents() {
  local CACHE_DIR=$1

  if [[ -d "$CACHE_DIR/agents" ]]; then
    for AGENT_FILE in "$CACHE_DIR"/agents/*.md; do
      if [[ -f "$AGENT_FILE" ]]; then
        basename "$AGENT_FILE" .md
      fi
    done
  fi
}
