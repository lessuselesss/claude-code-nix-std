{
  description = "comr - Claude-Open MCP Router for semantic MCP server selection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Helper to create workspace apps
      mkWorkspace = name: servers: description: "${pkgs.writeShellScript "${name}-workspace" ''
        #!/usr/bin/env bash
        set -euo pipefail

        WORKSPACE_CONFIG=$(mktemp)
        trap "rm -f '$WORKSPACE_CONFIG'" EXIT

        # Create workspace config
        cat > "$WORKSPACE_CONFIG" <<'EOF'
        ${builtins.toJSON { mcpServers = servers; }}
        EOF

        echo "🎯 Workspace: ${name}" >&2
        echo "📝 ${description}" >&2
        echo "🔧 Servers: $(${pkgs.jq}/bin/jq -r '.mcpServers | keys | join(", ")' "$WORKSPACE_CONFIG")" >&2
        echo "" >&2

        # Execute Claude Code with workspace config
        CLAUDE_SETTINGS="$WORKSPACE_CONFIG" ${pkgs.claude-code}/bin/claude -p "$@"
      ''}";


      # Helper to create workspace apps with agent support
      mkWorkspaceWithAgent = name: servers: agent: description: "${pkgs.writeShellScript "${name}-agent-workspace" ''
        #!/usr/bin/env bash
        set -euo pipefail

        WORKSPACE_CONFIG=$(mktemp)
        trap "rm -f '$WORKSPACE_CONFIG'" EXIT

        # Create workspace config
        cat > "$WORKSPACE_CONFIG" <<'EOF'
        ${builtins.toJSON { mcpServers = servers; }}
        EOF

        echo "🎯 Workspace: ${name}" >&2
        echo "🤖 Agent: ${agent.description}" >&2
        echo "🔧 Servers: $(${pkgs.jq}/bin/jq -r '.mcpServers | keys | join(", ")' "$WORKSPACE_CONFIG")" >&2
        echo "" >&2

        # Execute with agent
        CLAUDE_SETTINGS="$WORKSPACE_CONFIG" \
        ${pkgs.claude-code}/bin/claude \
          --agents '${builtins.toJSON { "${agent.name}" = { inherit (agent) description prompt; }; }}' \
          -p "$@"
      ''}";

      # Helper to create workspace apps with marketplace support
      mkWorkspaceWithMarketplaces = name: servers: marketplaces: description: "${pkgs.writeShellScript "${name}-marketplace-workspace" ''
        #!/usr/bin/env bash
        set -euo pipefail

        WORKSPACE_CONFIG=$(mktemp)
        PLUGIN_CACHE="$HOME/.config/comr/marketplaces"
        MARKETPLACE_PLUGINS=$(mktemp)
        FUZZY_MODE=false
        AGENT_MODE=false
        AGENT_NAME=""

        trap "rm -f '$WORKSPACE_CONFIG' '$MARKETPLACE_PLUGINS'" EXIT

        # Parse CLI arguments
        ARGS=()
        while [[ $# -gt 0 ]]; do
          case $1 in
            --ish)
              FUZZY_MODE=true
              shift
              ;;
            --agent)
              AGENT_MODE=true
              AGENT_NAME="$2"
              shift 2
              ;;
            *)
              ARGS+=("$1")
              shift
              ;;
          esac
        done

        # Marketplace URLs (from Nix)
        MARKETPLACES=(${builtins.concatStringsSep " " (map (m: ''"${m}"'') marketplaces)})

        # Fetch and cache marketplace plugins
        mkdir -p "$PLUGIN_CACHE"
        echo "{\"commands\": {}, \"agents\": {}}" > "$MARKETPLACE_PLUGINS"

        for MARKETPLACE_URL in "''${MARKETPLACES[@]}"; do
          REPO_HASH=$(echo -n "$MARKETPLACE_URL" | ${pkgs.coreutils}/bin/md5sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          CACHE_DIR="$PLUGIN_CACHE/$REPO_HASH"
          MARKETPLACE_JSON="$CACHE_DIR/marketplace.json"

          # Fetch marketplace.json if not cached or older than 24h
          if [[ ! -f "$MARKETPLACE_JSON" ]] || [[ $(${pkgs.findutils}/bin/find "$MARKETPLACE_JSON" -mtime +1 2>/dev/null | ${pkgs.coreutils}/bin/wc -l) -gt 0 ]]; then
            echo "📦 Fetching marketplace: $MARKETPLACE_URL" >&2
            mkdir -p "$CACHE_DIR"

            # Convert GitHub repo URL to raw .claude-plugin/marketplace.json URL
            MARKETPLACE_RAW_URL="''${MARKETPLACE_URL/github.com/raw.githubusercontent.com}/main/.claude-plugin/marketplace.json"

            if ${pkgs.curl}/bin/curl -sSfL "$MARKETPLACE_RAW_URL" -o "$MARKETPLACE_JSON" 2>&1; then
              echo "✅ Marketplace cached: $REPO_HASH" >&2
            else
              echo "⚠️  Failed to fetch marketplace: $MARKETPLACE_URL" >&2
              continue
            fi
          fi

          # Extract plugins from marketplace
          ${pkgs.jq}/bin/jq -r '.plugins[].source' "$MARKETPLACE_JSON" 2>/dev/null | while read -r PLUGIN_SOURCE; do
            if [[ -z "$PLUGIN_SOURCE" ]]; then continue; fi

            PLUGIN_DIR="$CACHE_DIR/''${PLUGIN_SOURCE#./}"
            mkdir -p "$PLUGIN_DIR/commands" "$PLUGIN_DIR/agents"

            # Convert GitHub repo URL to API URL
            REPO_PATH="''${MARKETPLACE_URL#https://github.com/}"
            API_BASE="https://api.github.com/repos/$REPO_PATH/contents"

            # Fetch commands
            COMMANDS_API="$API_BASE/''${PLUGIN_SOURCE#./}/commands"
            COMMANDS_JSON=$(${pkgs.curl}/bin/curl -sSfL "$COMMANDS_API" 2>/dev/null || echo "[]")

            if [[ "$COMMANDS_JSON" != "[]" ]]; then
              echo "$COMMANDS_JSON" | ${pkgs.jq}/bin/jq -r '.[].download_url' 2>/dev/null | while read -r DOWNLOAD_URL; do
                FILENAME=$(${pkgs.coreutils}/bin/basename "$DOWNLOAD_URL")
                OUTPUT_FILE="$PLUGIN_DIR/commands/$FILENAME"
                ${pkgs.curl}/bin/curl -sSfL "$DOWNLOAD_URL" -o "$OUTPUT_FILE" 2>/dev/null && \
                  echo "  ✓ Command: /''${FILENAME%.md}" >&2
              done
            fi

            # Fetch agents
            AGENTS_API="$API_BASE/''${PLUGIN_SOURCE#./}/agents"
            AGENTS_JSON=$(${pkgs.curl}/bin/curl -sSfL "$AGENTS_API" 2>/dev/null || echo "[]")

            if [[ "$AGENTS_JSON" != "[]" ]]; then
              echo "$AGENTS_JSON" | ${pkgs.jq}/bin/jq -r '.[].download_url' 2>/dev/null | while read -r DOWNLOAD_URL; do
                FILENAME=$(${pkgs.coreutils}/bin/basename "$DOWNLOAD_URL")
                OUTPUT_FILE="$PLUGIN_DIR/agents/$FILENAME"
                ${pkgs.curl}/bin/curl -sSfL "$DOWNLOAD_URL" -o "$OUTPUT_FILE" 2>/dev/null && \
                  echo "  ✓ Agent: ''${FILENAME%.md}" >&2
              done
            fi
          done
        done

        # Create workspace config
        cat > "$WORKSPACE_CONFIG" <<'EOF'
        ${builtins.toJSON { mcpServers = servers; }}
        EOF

        echo "🎯 Workspace: ${name}" >&2
        echo "📝 ${description}" >&2
        echo "🔧 Servers: $(${pkgs.jq}/bin/jq -r '.mcpServers | keys | join(", ")' "$WORKSPACE_CONFIG")" >&2
        echo "🏪 Marketplaces: ${toString (builtins.length marketplaces)}" >&2
        echo "" >&2

        # Helper: Find command in cache
        find_command() {
          local CMD_NAME=$1
          local FUZZY=$2

          for MARKETPLACE_URL in "''${MARKETPLACES[@]}"; do
            REPO_HASH=$(echo -n "$MARKETPLACE_URL" | ${pkgs.coreutils}/bin/md5sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
            CACHE_DIR="$PLUGIN_CACHE/$REPO_HASH"

            # Try exact match
            if [[ -f "$CACHE_DIR"/plugins/*/commands/"$CMD_NAME.md" ]]; then
              echo "$CACHE_DIR"/plugins/*/commands/"$CMD_NAME.md"
              return 0
            fi

            # Fuzzy match
            if [[ "$FUZZY" == "true" ]]; then
              local BEST_MATCH=""
              local BEST_SCORE=999

              for CMD_FILE in "$CACHE_DIR"/plugins/*/commands/*.md; do
                [[ ! -f "$CMD_FILE" ]] && continue
                local CMD=$(${pkgs.coreutils}/bin/basename "$CMD_FILE" .md)

                # Simple string similarity
                if [[ "$CMD" == *"$CMD_NAME"* ]] || [[ "$CMD_NAME" == *"$CMD"* ]]; then
                  BEST_MATCH="$CMD_FILE"
                  break
                fi
              done

              if [[ -n "$BEST_MATCH" ]]; then
                echo "$BEST_MATCH"
                return 0
              fi
            fi
          done

          return 1
        }

        # Helper: Find agent in cache
        find_agent() {
          local AGENT_NAME=$1
          local FUZZY=$2

          for MARKETPLACE_URL in "''${MARKETPLACES[@]}"; do
            REPO_HASH=$(echo -n "$MARKETPLACE_URL" | ${pkgs.coreutils}/bin/md5sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
            CACHE_DIR="$PLUGIN_CACHE/$REPO_HASH"

            # Try exact match
            if [[ -f "$CACHE_DIR"/plugins/*/agents/"$AGENT_NAME.md" ]]; then
              echo "$CACHE_DIR"/plugins/*/agents/"$AGENT_NAME.md"
              return 0
            fi

            # Fuzzy match
            if [[ "$FUZZY" == "true" ]]; then
              local BEST_MATCH=""

              for AGENT_FILE in "$CACHE_DIR"/plugins/*/agents/*.md; do
                [[ ! -f "$AGENT_FILE" ]] && continue
                local AGENT=$(${pkgs.coreutils}/bin/basename "$AGENT_FILE" .md)

                # Simple string similarity
                if [[ "$AGENT" == *"$AGENT_NAME"* ]] || [[ "$AGENT_NAME" == *"$AGENT"* ]]; then
                  BEST_MATCH="$AGENT_FILE"
                  break
                fi
              done

              if [[ -n "$BEST_MATCH" ]]; then
                echo "$BEST_MATCH"
                return 0
              fi
            fi
          done

          return 1
        }

        # Helper: List available commands
        list_commands() {
          for MARKETPLACE_URL in "''${MARKETPLACES[@]}"; do
            REPO_HASH=$(echo -n "$MARKETPLACE_URL" | ${pkgs.coreutils}/bin/md5sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
            CACHE_DIR="$PLUGIN_CACHE/$REPO_HASH"

            for CMD_FILE in "$CACHE_DIR"/plugins/*/commands/*.md; do
              [[ -f "$CMD_FILE" ]] && ${pkgs.coreutils}/bin/basename "$CMD_FILE" .md
            done
          done | ${pkgs.coreutils}/bin/sort -u
        }

        # Helper: List available agents
        list_agents() {
          for MARKETPLACE_URL in "''${MARKETPLACES[@]}"; do
            REPO_HASH=$(echo -n "$MARKETPLACE_URL" | ${pkgs.coreutils}/bin/md5sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
            CACHE_DIR="$PLUGIN_CACHE/$REPO_HASH"

            for AGENT_FILE in "$CACHE_DIR"/plugins/*/agents/*.md; do
              [[ -f "$AGENT_FILE" ]] && ${pkgs.coreutils}/bin/basename "$AGENT_FILE" .md
            done
          done | ${pkgs.coreutils}/bin/sort -u
        }

        # Check if first arg is a slash command
        PROMPT="''${ARGS[*]}"
        if [[ "$PROMPT" =~ ^/ ]]; then
          COMMAND_NAME="''${PROMPT%% *}"
          COMMAND_NAME="''${COMMAND_NAME#/}"
          COMMAND_ARGS="''${PROMPT#/* }"
          echo "🔍 Looking for slash command: /$COMMAND_NAME" >&2

          COMMAND_FILE=$(find_command "$COMMAND_NAME" "$FUZZY_MODE")
          if [[ -n "$COMMAND_FILE" ]]; then
            FOUND_CMD=$(${pkgs.coreutils}/bin/basename "$COMMAND_FILE" .md)
            if [[ "$FOUND_CMD" != "$COMMAND_NAME" ]]; then
              echo "✨ Using fuzzy match: /$FOUND_CMD (requested: /$COMMAND_NAME)" >&2
            fi
            # Read command and expand it as prompt
            PROMPT=$(${pkgs.coreutils}/bin/cat "$COMMAND_FILE")
            # Replace $ARGUMENTS placeholder
            PROMPT="''${PROMPT//\$ARGUMENTS/$COMMAND_ARGS}"
          else
            echo "❌ Error: Slash command '/$COMMAND_NAME' not found" >&2
            AVAILABLE=$(list_commands | ${pkgs.coreutils}/bin/head -5 | ${pkgs.coreutils}/bin/paste -sd ',' -)
            echo "" >&2
            echo "Available commands: $AVAILABLE" >&2
            echo "Hint: Use --ish for fuzzy matching" >&2
            exit 1
          fi
        fi

        # Execute Claude with marketplace plugins
        if [[ "$AGENT_MODE" == "true" ]]; then
          echo "🤖 Agent mode: $AGENT_NAME" >&2

          AGENT_FILE=$(find_agent "$AGENT_NAME" "$FUZZY_MODE")
          if [[ -n "$AGENT_FILE" ]]; then
            FOUND_AGENT=$(${pkgs.coreutils}/bin/basename "$AGENT_FILE" .md)
            if [[ "$FOUND_AGENT" != "$AGENT_NAME" ]]; then
              echo "✨ Using fuzzy match: $FOUND_AGENT (requested: $AGENT_NAME)" >&2
            fi
            # Read agent definition
            AGENT_CONTENT=$(${pkgs.coreutils}/bin/cat "$AGENT_FILE")
            # Extract description and prompt from markdown
            AGENT_DESC=$(echo "$AGENT_CONTENT" | ${pkgs.gnugrep}/bin/grep -m1 "^#" | ${pkgs.gnused}/bin/sed 's/^# //')
            AGENT_PROMPT="$AGENT_CONTENT"

            CLAUDE_SETTINGS="$WORKSPACE_CONFIG" ${pkgs.claude-code}/bin/claude \
              --agents "{\"$FOUND_AGENT\": {\"description\": \"$AGENT_DESC\", \"prompt\": $(echo "$AGENT_PROMPT" | ${pkgs.jq}/bin/jq -Rs .)}}" \
              -p "$PROMPT"
          else
            echo "❌ Error: Agent '$AGENT_NAME' not found" >&2
            AVAILABLE=$(list_agents | ${pkgs.coreutils}/bin/head -5 | ${pkgs.coreutils}/bin/paste -sd ',' -)
            echo "" >&2
            echo "Available agents: $AVAILABLE" >&2
            echo "Hint: Use --ish for fuzzy matching" >&2
            exit 1
          fi
        else
          CLAUDE_SETTINGS="$WORKSPACE_CONFIG" ${pkgs.claude-code}/bin/claude -p "$PROMPT"
        fi
      ''}";

    in
    {
      packages.${system}.default = pkgs.writeShellScriptBin "comr" ''
        #!/usr/bin/env bash
        # comr (Claude-Open MCP Router): Semantic MCP router for Claude Code
        # Architecture inspired by claude-code-open's provider routing pattern
        # Uses nix run for dynamic, reproducible MCP server execution

        set -euo pipefail

        USER_TASK="$*"

        if [[ -z "$USER_TASK" ]]; then
            cat << 'USAGE'
        Usage: comr <your task>

        Examples:
          comr "commit these changes"
          comr "review this PR for security issues"
          comr "test the login flow in browser"
          comr "explain how authentication works"

        This tool uses semantic analysis to load only the MCP servers needed for your task,
        dramatically reducing token usage compared to loading all servers.

        Full name: Claude-Open MCP Router (comr)
        USAGE
            exit 1
        fi

        # Configuration
        BASE_CONFIG="$HOME/.config/comr/servers.json"
        TEMP_CONFIG=$(mktemp)

        # Cleanup on exit - ensure Claude Code and MCP servers terminate cleanly
        CLAUDE_PID=""
        cleanup() {
          if [[ -n "$CLAUDE_PID" ]]; then
            # Send TERM signal to Claude Code process group
            kill -TERM -"$CLAUDE_PID" 2>/dev/null || true
            # Wait briefly for graceful shutdown
            sleep 0.5
            # Force kill if still running
            kill -KILL -"$CLAUDE_PID" 2>/dev/null || true
          fi
          rm -f "$TEMP_CONFIG"
        }
        trap cleanup EXIT INT TERM

        # Step 1: Load server registry and build intent prompt
        REGISTRY_FILE="$HOME/.config/comr/server-registry.json"

        # Build available servers list from both sources
        AVAILABLE_SERVERS=$(cat <<'EOF'
        # From servers.json (configured):
        - git: Version control operations (ALWAYS include)
        - sequential-thinking: Reasoning and chain-of-thought (ALWAYS include)
        - zen: Deep analysis, debugging, code review, consensus building
        - playwright: Browser automation, screenshots, E2E testing
        - github: GitHub operations, PRs, issues
        - context7: Library docs, API references
        - nixos: NixOS system operations
        - voicemode: Voice/audio interactions
        EOF
        )

        # Add registry servers if available
        if [[ -f "$REGISTRY_FILE" ]]; then
          REGISTRY_SERVERS=$(${pkgs.jq}/bin/jq -r '
            .servers | to_entries |
            map("- " + .key + ": " + .value.description + " (keywords: " + (.value.keywords // [] | join(", ")) + ")") |
            join("\n")
          ' "$REGISTRY_FILE" 2>/dev/null || echo "")

          if [[ -n "$REGISTRY_SERVERS" ]]; then
            AVAILABLE_SERVERS=$(cat <<EOF
        $AVAILABLE_SERVERS

        # From registry (auto-installable):
        $REGISTRY_SERVERS
        EOF
            )
          fi
        fi

        # Step 2: Semantic Intent Analysis (claude-code-open pattern)
        echo "🧠 Analyzing task intent..." >&2

        INTENT_ANALYSIS=$(cat <<EOF | ${pkgs.claude-code}/bin/claude -p --model "gemini-2.0-flash-lite" --output-format json --allowedTools ""
        Analyze this task and determine which MCP servers are needed.

        Available MCP servers:
        $AVAILABLE_SERVERS

        Rules:
        1. ALWAYS include "git" and "sequential-thinking" as baseline
        2. Add specialized servers ONLY if task explicitly needs them
        3. Minimize server count for token efficiency
        4. Prefer configured servers from servers.json over registry servers
        5. If unsure, use only baseline servers

        Task: $USER_TASK

        Return ONLY a valid JSON array of server names, e.g.: ["git", "sequential-thinking", "zen"]
        EOF
        )

        # Step 2: Parse server list with robust fallback
        SERVERS=$(echo "$INTENT_ANALYSIS" | ${pkgs.jq}/bin/jq -r '
          if type == "object" then
            .result // .servers // .mcpServers // ["git","sequential-thinking"]
          elif type == "array" then
            .
          else
            ["git","sequential-thinking"]
          end |
          if (. | length) == 0 then ["git","sequential-thinking"] else . end |
          @json' 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[]' 2>/dev/null | paste -sd, || echo "git,sequential-thinking")

        echo "📋 Selected servers: [$SERVERS]" >&2

        # Step 3: Transform server definitions to Claude settings format
        # First try configured servers, then fall back to registry
        CONFIG_SERVERS=$(${pkgs.jq}/bin/jq --arg servers "$SERVERS" '
          .mcpServers |
          with_entries(select(.key | IN($servers | split(",")[]))) |
          to_entries |
          map(
            if .value.type == "flake" then
              {
                key: .key,
                value: {
                  command: "nix",
                  args: (["run", .value.flake, "--"] + (.value.args // [])),
                  env: (.value.env // {})
                }
              }
            elif .value.type == "package" then
              {
                key: .key,
                value: {
                  command: .value.command,
                  args: .value.args,
                  env: (.value.env // {})
                }
              }
            elif .value.type == "executable" then
              {
                key: .key,
                value: {
                  command: .value.command,
                  args: (.value.args // []),
                  env: (.value.env // {})
                }
              }
            else
              {key: .key, value: .value}
            end
          ) |
          from_entries
        ' "$BASE_CONFIG" 2>/dev/null || echo '{}')

        # Check registry for missing servers
        if [[ -f "$REGISTRY_FILE" ]]; then
          REGISTRY_SERVERS=$(${pkgs.jq}/bin/jq --arg servers "$SERVERS" --argjson configured "$CONFIG_SERVERS" '
            .servers |
            with_entries(
              select(
                (.key | IN($servers | split(",")[])) and
                ($configured | has(.key) | not)
              )
            ) |
            to_entries |
            map({
              key: .key,
              value: {
                command: .value.command,
                args: .value.args,
                env: (.value.env // {})
              }
            }) |
            from_entries
          ' "$REGISTRY_FILE" 2>/dev/null || echo '{}')

          # Merge configured and registry servers
          MERGED_SERVERS=$(${pkgs.jq}/bin/jq -n --argjson config "$CONFIG_SERVERS" --argjson registry "$REGISTRY_SERVERS" '
            $config + $registry
          ')
        else
          MERGED_SERVERS="$CONFIG_SERVERS"
        fi

        # Write final config
        echo "$MERGED_SERVERS" | ${pkgs.jq}/bin/jq '{mcpServers: .}' > "$TEMP_CONFIG" 2>/dev/null || {
            echo "⚠️  Warning: Failed to parse config, using fallback" >&2
            echo '{"mcpServers": {}}' > "$TEMP_CONFIG"
        }

        # Verify config has servers
        SERVER_COUNT=$(${pkgs.jq}/bin/jq -e '.mcpServers | length' "$TEMP_CONFIG" 2>/dev/null || echo "0")

        if [[ "$SERVER_COUNT" -eq 0 ]]; then
            echo "❌ Error: No MCP servers selected, using base config as fallback" >&2
            ${pkgs.jq}/bin/jq --arg servers "git,sequential-thinking" '
              .mcpServers |
              with_entries(select(.key | IN($servers | split(",")[]))) |
              to_entries |
              map(
                if .value.type == "package" then
                  {key: .key, value: {command: .value.command, args: .value.args, env: (.value.env // {})}}
                else
                  {key: .key, value: .value}
                end
              ) |
              from_entries |
              {mcpServers: .}
            ' "$BASE_CONFIG" > "$TEMP_CONFIG"
        fi

        # Show loaded servers
        echo "✅ MCP servers loaded: $(${pkgs.jq}/bin/jq -r '.mcpServers | keys | join(", ")' "$TEMP_CONFIG")" >&2
        echo "" >&2

        # Step 4: Execute Claude Code with optimized server selection
        # Run in background to capture PID for cleanup
        CLAUDE_SETTINGS="$TEMP_CONFIG" ${pkgs.claude-code}/bin/claude -p "$USER_TASK" &
        CLAUDE_PID=$!

        # Wait for Claude Code to complete
        wait $CLAUDE_PID
        EXIT_CODE=$?

        # Clear PID to prevent cleanup from killing again
        CLAUDE_PID=""

        exit $EXIT_CODE
      '';

      # Workspace apps for Director-like functionality
      apps.${system} = {
        # Default: comr with semantic routing
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/comr";
        };

        # Python development workspace
        python-dev = {
          type = "app";
          program = mkWorkspace "python-dev"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              sqlite = {
                command = "npx";
                args = ["-y" "mcp-sqlite"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            "Python development with SQLite and filesystem access";
        };

        # Web development workspace
        web-dev = {
          type = "app";
          program = mkWorkspace "web-dev"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              playwright = {
                command = "nix";
                args = ["run" "github:modelcontextprotocol/servers/main#playwright" "--"];
              };
              github = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-github"];
              };
              brave-search = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-brave-search"];
              };
            }
            "Web development with browser automation and GitHub integration";
        };

        # Data analysis workspace
        data-analysis = {
          type = "app";
          program = mkWorkspace "data-analysis"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              postgres = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-postgres"];
              };
              sqlite = {
                command = "npx";
                args = ["-y" "mcp-sqlite"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            "Data analysis with PostgreSQL, SQLite, and filesystem access";
        };

        # DevOps workspace
        devops = {
          type = "app";
          program = mkWorkspace "devops"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              docker = {
                command = "uvx";
                args = ["mcp-server-docker"];
              };
              aws = {
                command = "uvx";
                args = ["awslabs-mcp-server"];
              };
              github = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-github"];
              };
            }
            "DevOps with Docker, AWS, and GitHub integration";
        };

        # API development workspace
        api-dev = {
          type = "app";
          program = mkWorkspace "api-dev"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              postgres = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-postgres"];
              };
              slack = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-slack"];
              };
              stripe = {
                command = "npx";
                args = ["-y" "@stripe/agent-toolkit"];
              };
            }
            "API development with database, Slack, and Stripe integration";
        };

        # Agent-enhanced workspaces
        security-audit = {
          type = "app";
          program = mkWorkspaceWithAgent "security-audit"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            {
              name = "security";
              description = "Security auditor";
              prompt = "You are a security auditor. Scan for OWASP Top 10 vulnerabilities: 1) SQL Injection, 2) XSS, 3) Broken Authentication, 4) Sensitive Data Exposure, 5) XML External Entities, 6) Broken Access Control, 7) Security Misconfiguration, 8) Insecure Deserialization, 9) Using Components with Known Vulnerabilities, 10) Insufficient Logging & Monitoring. Report findings with severity levels (critical/high/medium/low) and remediation steps.";
            }
            "Security audit workspace with specialized security agent";
        };

        code-review = {
          type = "app";
          program = mkWorkspaceWithAgent "code-review"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            {
              name = "reviewer";
              description = "Senior code reviewer";
              prompt = "You are a senior code reviewer with 15+ years of experience. Focus on: 1) Security vulnerabilities, 2) Performance issues, 3) Code maintainability, 4) Design patterns, 5) Best practices, 6) Test coverage. Be thorough, critical, and constructive. Provide specific examples and actionable recommendations.";
            }
            "Code review workspace with senior reviewer agent";
        };

        refactor = {
          type = "app";
          program = mkWorkspaceWithAgent "refactor"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            {
              name = "refactorer";
              description = "Refactoring specialist";
              prompt = "You are a refactoring specialist. Identify code smells: 1) Long methods, 2) Large classes, 3) Duplicate code, 4) Complex conditionals, 5) Poor naming. Suggest design patterns (Strategy, Factory, Observer, etc.) and create step-by-step refactoring plans. Prioritize readability, testability, and maintainability.";
            }
            "Refactoring workspace with specialist agent";
        };

        perf-optimize = {
          type = "app";
          program = mkWorkspaceWithAgent "perf-optimize"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              postgres = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-postgres"];
              };
              sqlite = {
                command = "npx";
                args = ["-y" "mcp-sqlite"];
              };
            }
            {
              name = "optimizer";
              description = "Performance optimization expert";
              prompt = "You are a performance optimization expert. Identify: 1) Slow algorithms (O(n²) or worse), 2) Database N+1 problems, 3) Missing indexes, 4) Blocking I/O operations, 5) Memory leaks, 6) Unnecessary loops. Provide specific optimizations with expected performance impact (e.g., '10x speedup by adding index').";
            }
            "Performance optimization workspace";
        };

        accessibility-check = {
          type = "app";
          program = mkWorkspaceWithAgent "accessibility-check"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              playwright = {
                command = "nix";
                args = ["run" "github:modelcontextprotocol/servers/main#playwright" "--"];
              };
            }
            {
              name = "a11y";
              description = "Accessibility expert";
              prompt = "You are a WCAG 2.1 AA accessibility expert. Check for: 1) Keyboard navigation, 2) Screen reader support, 3) Color contrast (4.5:1 text, 3:1 UI), 4) ARIA labels, 5) Focus management, 6) Alt text, 7) Form labels, 8) Heading structure. Test with Playwright and report violations with remediation steps.";
            }
            "Accessibility testing workspace";
        };

        # BAML extraction workspace - Type-safe structured data extraction
        baml-extract = {
          type = "app";
          program = mkWorkspaceWithAgent "baml-extract"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            {
              name = "baml-extractor";
              description = "BAML data extraction specialist";
              prompt = "You are a data extraction specialist using BAML (Boundary AI Markup Language) for type-safe structured outputs. Core Capabilities: 1) Extract structured data from unstructured text (resumes, invoices, contracts, logs), 2) Type-safe parsing with automatic validation and retry on failures, 3) Handle missing/ambiguous information gracefully with optional fields, 4) Parse and validate git status, API responses, and tool outputs. BAML Functions Available: ExtractResume(text)->Resume, ExtractResumeHQ(text)->Resume (high-quality), ExtractInvoice(text)->Invoice, ExtractContract(text)->Contract, ParseGitStatus(output)->GitStatus. ALWAYS use BAML functions for structured data extraction. Validate outputs against BAML schemas automatically. Handle BamlValidationError with full context. Use optional fields (?) for missing data. Never return unvalidated JSON strings. BAML Source: ~/.config/comr/baml_src/";
            }
            "BAML-powered type-safe data extraction workspace";
        };

        # Hacker News frontpage fetcher
        hackernews = {
          type = "app";
          program = mkWorkspaceWithAgent "hackernews"
            {
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              brave-search = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-brave-search"];
              };
            }
            {
              name = "hn-curator";
              description = "Hacker News curator";
              prompt = "You are a Hacker News curator. Your role: 1) Fetch the current Hacker News frontpage (use Brave Search or direct API calls), 2) Extract top stories with titles, URLs, points, and comment counts, 3) Summarize interesting stories, 4) Identify trending topics and themes, 5) Highlight technical discussions worth reading. Present results in a clean, readable format with story rankings, key insights, and why each story matters to developers/tech enthusiasts.";
            }
            "Hacker News frontpage fetcher and curator";
        };

        # Agent Gateway - AI agent connectivity and orchestration
        agent-gateway = {
          type = "app";
          program = mkWorkspaceWithAgent "agent-gateway"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
              github = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-github"];
              };
            }
            {
              name = "gateway-specialist";
              description = "Agent Gateway specialist";
              prompt = "You are an Agent Gateway specialist for configuring and managing AI agent connectivity. Agent Gateway is a Rust-based data plane for agent-to-agent (A2A) and agent-to-tool communication supporting MCP and A2A protocols. Core responsibilities: 1) Configure multi-tenant gateway deployments with RBAC, 2) Transform legacy APIs into MCP resources (OpenAPI support), 3) Set up agent-to-agent communication channels, 4) Implement observability and governance for agent interactions, 5) Manage dynamic configuration updates via xDS, 6) Secure agent communication with authentication and authorization. The gateway runs as a standalone binary (agentgateway) and provides a web UI for management. Focus on security-first design, multi-tenancy, and high-performance agent orchestration. Reference: https://agentgateway.dev";
            }
            "Agent Gateway configuration and AI agent orchestration workspace";
        };

        # Hugging Face - ML model and dataset exploration
        huggingface = {
          type = "app";
          program = mkWorkspace "huggingface"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              huggingface = {
                command = "nix";
                args = ["run" "github:modelcontextprotocol/servers/main#huggingface" "--"];
                env = {
                  HF_TOKEN = "$HF_TOKEN";
                };
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            "Hugging Face Hub: search models, datasets, papers, and Gradio Spaces";
        };

        # Web Research - Advanced web search and research
        web-research = {
          type = "app";
          program = mkWorkspace "web-research"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              exa = {
                command = "npx";
                args = ["-y" "exa-mcp-server"];
              };
              brave-search = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-brave-search"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            "Advanced web research with Exa AI (web search, code search, company research, crawling)";
        };

        # Example: Web development with Every marketplace
        web-dev-marketplace = {
          type = "app";
          program = mkWorkspaceWithMarketplaces "web-dev-marketplace"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              playwright = {
                command = "nix";
                args = ["run" "github:modelcontextprotocol/servers/main#playwright" "--"];
              };
              github = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-github"];
              };
            }
            ["https://github.com/EveryInc/every-marketplace"]
            "Web development with Every marketplace (code review, planning, workflow automation)";
        };

        # Zen Agents - Multi-model AI workspace with zen-mcp-server
        zen-agents = {
          type = "app";
          program = mkWorkspaceWithAgent "zen-agents"
            {
              git = {
                command = "uvx";
                args = ["mcp-server-git"];
              };
              sequential-thinking = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-sequential-thinking"];
              };
              zen = {
                command = "nix";
                args = ["run" "github:BeehiveInnovations/zen-mcp-server" "--"];
                env = {
                  GEMINI_API_KEY = "$GEMINI_API_KEY";
                  OPENROUTER_API_KEY = "$OPENROUTER_API_KEY";
                  DISABLED_TOOLS = "analyze,refactor,testgen,secaudit,docgen,tracer";
                  DEFAULT_MODEL = "auto";
                  ZEN_CLI_CLIENTS = builtins.toJSON {
                    gemini = {
                      command = "gemini";
                      roles = {
                        default = {
                          name = "Gemini Assistant";
                          instructions = "You are a helpful AI assistant powered by Google Gemini.";
                        };
                        planner = {
                          name = "Gemini Planner";
                          instructions = "You are a strategic planner. Break down complex tasks into actionable steps.";
                        };
                        codereviewer = {
                          name = "Gemini Code Reviewer";
                          instructions = "You are an expert code reviewer. Analyze code for bugs, security issues, and best practices.";
                        };
                      };
                    };
                    codex = {
                      command = "codex";
                      roles = {
                        default = {
                          name = "Codex Assistant";
                          instructions = "You are a code generation specialist powered by OpenAI Codex.";
                        };
                      };
                    };
                    claude = {
                      command = "claude";
                      roles = {
                        default = {
                          name = "Claude Assistant";
                          instructions = "You are Claude, an AI assistant by Anthropic.";
                        };
                      };
                    };
                  };
                };
              };
              context7 = {
                command = "npx";
                args = ["-y" "@upstash/context7-mcp"];
              };
              filesystem = {
                command = "npx";
                args = ["-y" "@modelcontextprotocol/server-filesystem"];
              };
            }
            {
              name = "zen-orchestrator";
              description = "Zen multi-model orchestrator";
              prompt = "You are a multi-model AI orchestrator using the Zen MCP server. Core capabilities: 1) Access multiple AI models: Gemini (via GEMINI_API_KEY), GPT-4/Claude (via OPENROUTER_API_KEY), and local models via Qwen/Codex CLIs. 2) Use the 'chat' tool for collaborative thinking and brainstorming with different models. 3) Use 'thinkdeep' for multi-stage investigation and complex problem analysis. 4) Use 'planner' for breaking down complex tasks through sequential planning. 5) Use 'consensus' for multi-model decision making through structured debate. 6) Use 'codereview' for systematic code review with expert validation. 7) Use 'debug' for root cause analysis. 8) Use 'clink' to delegate tasks to external CLIs (gemini, codex, qwen). 9) Leverage Context7 for up-to-date library documentation. Model selection: Use 'gemini-2.5-pro' for complex reasoning, 'gemini-2.0-flash' for speed, or let DEFAULT_MODEL='auto' choose automatically. When facing complex problems, use thinkdeep or consensus to leverage multiple perspectives. For implementation tasks requiring specific CLI expertise, use clink to delegate (e.g., 'clink gemini for ML tasks', 'clink codex for code generation'). Always specify model, working_directory, and files when using zen tools.";
            }
            "Multi-model AI workspace with Zen MCP server (Gemini, OpenRouter, CLI agents)";
        };
      };
    };
}
