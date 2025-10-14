# MCP Cell - Universal Model Context Protocol Server Registry

## Purpose

Provide universal MCP server registry and management across all CLI agent ecosystems (Claude Code, Gemini CLI, Qwen). Single source of truth for 100+ MCP servers with ecosystem compatibility mappings.

## Key Features

- **Universal Registry**: 100+ MCP servers catalogued
- **Multi-Provider Support**: npm (npx), pip (uvx), nix (flakes)
- **Compatibility Matrix**: Which servers work with which agents
- **Auto-Discovery**: Find servers by capability/keyword
- **Type System**: Categorize by purpose (database, api, filesystem, etc.)

## Three-Layer API

**Layer 1:**
```nix
mcp.getServer "git"
mcp.getServer "postgres"
mcp.findServers ["database" "sql"]
```

**Layer 2:**
```nix
mcp.buildServer {
  name = "custom-server";
  provider = "npm";
  package = "@org/mcp-custom";
}
```

**Layer 3:**
```nix
mcp.mkServer {
  name = "...";
  command = "npx" | "uvx" | "nix";
  args = [...];
  env = {...};
  capabilities = [...];
}
```

## Files

```
cells/mcp/
├── CLAUDE.md
├── lib.nix          # Server management API
├── data.nix         # Universal server registry
├── functions.nix    # Server discovery, routing
└── runnables.nix    # Server test runners
```

## Implementation Plan

### Phase 1: Server Registry (Week 3, Days 1-3)

**data.nix:**
```nix
{
  servers = {
    git = {
      providers = {
        npm = "@modelcontextprotocol/server-git";
        pip = "mcp-server-git";
        nix = "github:modelcontextprotocol/servers#git";
      };
      capabilities = ["version-control" "diff" "commit" "branch"];
      ecosystems = ["claude-code" "gemini-cli" "qwen"];
      keywords = ["git" "version" "control" "commit" "diff"];
      description = "Git version control operations";
    };

    postgres = {
      providers = {
        npm = "@modelcontextprotocol/server-postgres";
      };
      capabilities = ["database" "sql" "query"];
      ecosystems = ["claude-code" "gemini-cli"];
      keywords = ["postgres" "postgresql" "database" "sql"];
      description = "PostgreSQL database operations";
    };

    github = {
      providers = {
        npm = "@modelcontextprotocol/server-github";
      };
      capabilities = ["api" "github" "issues" "prs"];
      ecosystems = ["claude-code" "gemini-cli"];
      keywords = ["github" "issues" "prs" "repositories"];
      description = "GitHub API operations";
      env = { GITHUB_TOKEN = "$GITHUB_TOKEN"; };
    };

    playwright = {
      providers = {
        nix = "github:modelcontextprotocol/servers/main#playwright";
      };
      capabilities = ["browser" "automation" "testing"];
      ecosystems = ["claude-code" "gemini-cli"];
      keywords = ["browser" "playwright" "testing" "e2e"];
      description = "Browser automation with Playwright";
    };

    stripe = {
      providers = {
        npm = "@stripe/agent-toolkit";
      };
      capabilities = ["payments" "api"];
      ecosystems = ["claude-code" "gemini-cli"];
      keywords = ["stripe" "payments" "billing"];
      description = "Stripe payment operations";
      env = { STRIPE_API_KEY = "$STRIPE_API_KEY"; };
    };

    sqlite = {
      providers = {
        npm = "mcp-sqlite";
      };
      capabilities = ["database" "sql" "query"];
      ecosystems = ["claude-code"];
      keywords = ["sqlite" "database" "sql" "embedded"];
      description = "SQLite database operations";
    };

    slack = {
      providers = {
        npm = "@modelcontextprotocol/server-slack";
      };
      capabilities = ["messaging" "api"];
      ecosystems = ["claude-code" "gemini-cli"];
      keywords = ["slack" "messaging" "notifications"];
      description = "Slack messaging operations";
      env = { SLACK_TOKEN = "$SLACK_TOKEN"; };
    };

    docker = {
      providers = {
        pip = "mcp-server-docker";
      };
      capabilities = ["containers" "devops"];
      ecosystems = ["claude-code" "qwen"];
      keywords = ["docker" "containers" "devops"];
      description = "Docker container operations";
    };

    aws = {
      providers = {
        pip = "awslabs-mcp-server";
      };
      capabilities = ["cloud" "devops" "infrastructure"];
      ecosystems = ["claude-code"];
      keywords = ["aws" "cloud" "ec2" "s3"];
      description = "AWS cloud operations";
      env = { AWS_ACCESS_KEY_ID = "$AWS_ACCESS_KEY_ID"; AWS_SECRET_ACCESS_KEY = "$AWS_SECRET_ACCESS_KEY"; };
    };

    huggingface = {
      providers = {
        nix = "github:modelcontextprotocol/servers/main#huggingface";
      };
      capabilities = ["ml" "models" "datasets"];
      ecosystems = ["claude-code"];
      keywords = ["huggingface" "ml" "models" "datasets"];
      description = "Hugging Face Hub operations";
      env = { HF_TOKEN = "$HF_TOKEN"; };
    };

    "sequential-thinking" = {
      providers = {
        npm = "@modelcontextprotocol/server-sequential-thinking";
      };
      capabilities = ["reasoning" "cot"];
      ecosystems = ["claude-code" "gemini-cli" "qwen"];
      keywords = ["thinking" "reasoning" "chain-of-thought"];
      description = "Sequential thinking and reasoning";
    };

    filesystem = {
      providers = {
        npm = "@modelcontextprotocol/server-filesystem";
      };
      capabilities = ["filesystem" "files"];
      ecosystems = ["claude-code" "gemini-cli" "qwen"];
      keywords = ["filesystem" "files" "directories"];
      description = "Filesystem operations";
    };

    "brave-search" = {
      providers = {
        npm = "@modelcontextprotocol/server-brave-search";
      };
      capabilities = ["search" "web"];
      ecosystems = ["claude-code"];
      keywords = ["search" "web" "brave"];
      description = "Brave Search operations";
      env = { BRAVE_API_KEY = "$BRAVE_API_KEY"; };
    };

    exa = {
      providers = {
        npm = "exa-mcp-server";
      };
      capabilities = ["search" "web" "research"];
      ecosystems = ["claude-code"];
      keywords = ["search" "exa" "research"];
      description = "Exa AI web research";
    };

    zen = {
      providers = {
        nix = "github:BeehiveInnovations/zen-mcp-server";
      };
      capabilities = ["orchestration" "multi-model"];
      ecosystems = ["claude-code"];
      keywords = ["zen" "orchestration" "multi-model"];
      description = "Zen multi-model orchestration";
      env = {
        GEMINI_API_KEY = "$GEMINI_API_KEY";
        OPENROUTER_API_KEY = "$OPENROUTER_API_KEY";
      };
    };

    strata = {
      providers = {
        pip = "strata-mcp";
      };
      capabilities = ["routing" "discovery"];
      ecosystems = ["claude-code" "gemini-cli"];
      keywords = ["strata" "routing" "progressive-discovery"];
      description = "Strata progressive tool discovery router";
    };

    context7 = {
      providers = {
        npm = "@upstash/context7-mcp";
      };
      capabilities = ["documentation" "rag"];
      ecosystems = ["claude-code"];
      keywords = ["context7" "documentation" "rag"];
      description = "Context7 documentation retrieval";
    };

    # ... 85+ more servers
  };

  # Compatibility matrix
  compatibility = {
    claude-code = builtins.filter (s: builtins.elem "claude-code" servers.${s}.ecosystems) (builtins.attrNames servers);
    gemini-cli = builtins.filter (s: builtins.elem "gemini-cli" servers.${s}.ecosystems) (builtins.attrNames servers);
    qwen = builtins.filter (s: builtins.elem "qwen" servers.${s}.ecosystems) (builtins.attrNames servers);
  };
}
```

### Phase 2: Server Discovery API (Week 3, Days 4-5)

**lib.nix:**
```nix
{inputs, cell}: rec {
  # High-level: Get server by name
  getServer = name:
    if builtins.hasAttr name cell.data.servers
    then cell.functions.buildServer cell.data.servers.${name}
    else throw "Unknown MCP server: ${name}";

  # High-level: Find servers by capability
  findByCapability = capability:
    builtins.filter (s:
      builtins.elem capability cell.data.servers.${s}.capabilities
    ) (builtins.attrNames cell.data.servers);

  # High-level: Find servers by keyword
  findByKeyword = keyword:
    builtins.filter (s:
      builtins.elem keyword cell.data.servers.${s}.keywords
    ) (builtins.attrNames cell.data.servers);

  # High-level: Get servers for ecosystem
  getForEcosystem = ecosystem:
    cell.data.compatibility.${ecosystem} or [];

  # Medium-level: Build custom server
  buildServer = serverDef:
    let
      # Choose provider (prefer npm > pip > nix)
      provider = if serverDef.providers ? npm
                 then "npm"
                 else if serverDef.providers ? pip
                 then "pip"
                 else "nix";

      package = serverDef.providers.${provider};
    in cell.functions.mkServerConfig {
      name = serverDef.name;
      inherit provider package;
      env = serverDef.env or {};
    };

  # Low-level: Create raw server config
  mkServer = { name, command, args, env ? {}, capabilities ? [] }:
    { inherit name command args env capabilities; };
}
```

### Phase 3: Server Transformation (Week 3, Days 6-7)

**functions.nix:**
```nix
{inputs, cell}: rec {
  # Transform server definition to runtime config
  mkServerConfig = { name, provider, package, env ? {} }:
    if provider == "npm"
    then {
      inherit name;
      command = "npx";
      args = ["-y" package];
      env = env;
    }
    else if provider == "pip"
    then {
      inherit name;
      command = "uvx";
      args = [package];
      env = env;
    }
    else if provider == "nix"
    then {
      inherit name;
      command = "nix";
      args = ["run" package "--"];
      env = env;
    }
    else throw "Unknown provider: ${provider}";

  # Search servers by query
  searchServers = query:
    let
      queryLower = builtins.toLower query;
      matches = builtins.filter (serverName:
        let
          server = cell.data.servers.${serverName};
          matchesKeyword = builtins.any (k: builtins.match ".*${queryLower}.*" k != null) server.keywords;
          matchesDesc = builtins.match ".*${queryLower}.*" (builtins.toLower server.description) != null;
        in matchesKeyword || matchesDesc
      ) (builtins.attrNames cell.data.servers);
    in matches;

  # Check server compatibility
  isCompatible = serverName: ecosystem:
    let server = cell.data.servers.${serverName};
    in builtins.elem ecosystem server.ecosystems;
}
```

### Phase 4: Registry Maintenance & Auto-Sync (Week 4, Days 1-3)

#### Complete Server List Strategy

The registry aims for 100+ servers. Rather than hardcoding all, we use a hybrid approach:

**Core Servers (hardcoded in data.nix):**
- Essential: git, sequential-thinking, filesystem
- Popular: github, postgres, sqlite, slack, stripe
- Specialized: zen, strata, playwright, huggingface, docker, aws
- Total: ~30 most commonly used servers

**Extended Registry (auto-fetched):**
```nix
# data.nix - Add extended registry sources
{
  extendedRegistries = {
    mcp-official = {
      url = "https://github.com/modelcontextprotocol/servers";
      type = "github-repo";
      sync_interval = "daily";
      discover_method = "list-packages";  # npm/pip packages in repo
    };

    community-registry = {
      url = "https://mcp-registry.dev/api/v1/servers.json";
      type = "json-api";
      sync_interval = "weekly";
      discover_method = "fetch-json";
    };

    awesome-mcp = {
      url = "https://github.com/awesome-mcp/servers";
      type = "curated-list";
      sync_interval = "weekly";
      discover_method = "parse-readme";
    };
  };
}
```

#### Auto-Sync Mechanism

**runnables.nix - Registry Sync Tool:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  sync-registry = pkgs.writeShellScriptBin "sync-mcp-registry" ''
    #!/usr/bin/env bash
    set -euo pipefail

    OUTPUT_DIR="./cells/mcp/generated"
    mkdir -p "$OUTPUT_DIR"

    echo "🔄 Syncing MCP Server Registry..."

    # Sync from MCP official repo
    echo "📦 Fetching from modelcontextprotocol/servers..."
    ${pkgs.gh}/bin/gh api repos/modelcontextprotocol/servers/contents \
      | ${pkgs.jq}/bin/jq -r '.[] | select(.type == "dir") | .name' \
      > "$OUTPUT_DIR/official-servers.txt"

    # Convert to Nix format
    ${pkgs.python3}/bin/python3 ${./scripts/generate-registry.py} \
      --official-list "$OUTPUT_DIR/official-servers.txt" \
      --output "$OUTPUT_DIR/registry.nix"

    echo "✅ Registry synced. Found $(wc -l < $OUTPUT_DIR/official-servers.txt) official servers"
  '';

  # Generate compatibility matrix
  generate-compatibility = pkgs.writeShellScriptBin "generate-compatibility" ''
    #!/usr/bin/env bash
    # Test each server with each ecosystem
    # Generate compatibility.json
  '';
}
```

**scripts/generate-registry.py:**
```python
#!/usr/bin/env python3
"""
Generate Nix registry from upstream MCP sources.
"""
import json
import re
from pathlib import Path

def discover_npm_servers():
    """Find npm MCP servers from @modelcontextprotocol org."""
    # Search npm registry
    servers = []
    # ... npm search logic
    return servers

def discover_pip_servers():
    """Find pip MCP servers."""
    # Search PyPI
    servers = []
    # ... PyPI search logic
    return servers

def generate_nix_registry(servers):
    """Convert servers list to Nix format."""
    nix_code = "{\n  extendedServers = {\n"

    for server in servers:
        nix_code += f'''
    "{server['name']}" = {{
      providers = {{
        {server['provider']} = "{server['package']}";
      }};
      capabilities = {server['capabilities']};
      ecosystems = {server['ecosystems']};
      keywords = {server['keywords']};
      description = "{server['description']}";
    }};
'''

    nix_code += "  };\n}\n"
    return nix_code

def main():
    # Discover servers from multiple sources
    npm_servers = discover_npm_servers()
    pip_servers = discover_pip_servers()

    all_servers = npm_servers + pip_servers

    # Generate Nix registry
    nix_registry = generate_nix_registry(all_servers)

    # Write to file
    with open('generated/registry.nix', 'w') as f:
        f.write(nix_registry)

    print(f"Generated registry with {len(all_servers)} servers")

if __name__ == '__main__':
    main()
```

**data.nix - Import generated registry:**
```nix
{
  # Core servers (manually curated)
  servers = {
    git = { /* ... */ };
    postgres = { /* ... */ };
    # ... 30 core servers
  };

  # Extended servers (auto-generated)
  extendedServers = import ./generated/registry.nix;

  # Merge core + extended
  allServers = servers // extendedServers.extendedServers;
}
```

#### Version Management

**Server Versioning:**
```nix
# data.nix - Add version tracking
{
  servers = {
    git = {
      version = "1.2.0";  # Track version
      providers = {
        npm = "@modelcontextprotocol/server-git@1.2.0";  # Pin version
        pip = "mcp-server-git==1.2.0";
        nix = "github:modelcontextprotocol/servers/v1.2.0#git";
      };
      last_updated = "2025-01-15";
      changelog_url = "https://github.com/modelcontextprotocol/servers/releases/tag/v1.2.0";
    };
  };

  # Version lock file (similar to package-lock.json)
  locks = {
    git = {
      npm_hash = "sha256:abc123...";
      pip_hash = "sha256:def456...";
      nix_hash = "sha256:ghi789...";
    };
  };
}
```

**Version Update Tool:**
```nix
# runnables.nix
{
  update-server = pkgs.writeShellScriptBin "update-mcp-server" ''
    #!/usr/bin/env bash
    SERVER_NAME="$1"
    NEW_VERSION="$2"

    echo "📦 Updating $SERVER_NAME to $NEW_VERSION..."

    # Fetch new package info
    NPM_PACKAGE=$(npm view "@modelcontextprotocol/server-$SERVER_NAME@$NEW_VERSION" --json)
    NPM_HASH=$(echo "$NPM_PACKAGE" | jq -r '.dist.shasum')

    # Update data.nix
    ${pkgs.gnused}/bin/sed -i \
      "s|$SERVER_NAME = { version = \"[^\"]*\"|$SERVER_NAME = { version = \"$NEW_VERSION\"|" \
      cells/mcp/data.nix

    echo "✅ Updated $SERVER_NAME to $NEW_VERSION"
  '';

  # Bulk update check
  check-updates = pkgs.writeShellScriptBin "check-mcp-updates" ''
    #!/usr/bin/env bash
    echo "🔍 Checking for MCP server updates..."

    # For each server, check if new version available
    for SERVER in git postgres github slack; do
      CURRENT=$(nix eval ".#mcp.data.servers.$SERVER.version" --raw)
      LATEST=$(npm view "@modelcontextprotocol/server-$SERVER" version)

      if [[ "$CURRENT" != "$LATEST" ]]; then
        echo "⚠️  $SERVER: $CURRENT → $LATEST (update available)"
      else
        echo "✅ $SERVER: $CURRENT (up to date)"
      fi
    done
  '';
}
```

#### Compatibility Testing

**Test Matrix:**
```nix
# runnables.nix - Compatibility tester
{
  test-compatibility = pkgs.writeShellScriptBin "test-mcp-compatibility" ''
    #!/usr/bin/env bash
    set -euo pipefail

    OUTPUT="./cells/mcp/compatibility-matrix.json"
    echo "{}" > "$OUTPUT"

    # Test each server with each ecosystem
    for SERVER in git postgres github slack; do
      echo "Testing $SERVER..."

      # Test with Claude Code
      if test-with-claude-code "$SERVER"; then
        ${pkgs.jq}/bin/jq ".\"$SERVER\".claude_code = true" "$OUTPUT" > tmp && mv tmp "$OUTPUT"
      fi

      # Test with Gemini CLI
      if test-with-gemini "$SERVER"; then
        ${pkgs.jq}/bin/jq ".\"$SERVER\".gemini_cli = true" "$OUTPUT" > tmp && mv tmp "$OUTPUT"
      fi

      # Test with Qwen
      if test-with-qwen "$SERVER"; then
        ${pkgs.jq}/bin/jq ".\"$SERVER\".qwen = true" "$OUTPUT" > tmp && mv tmp "$OUTPUT"
      fi
    done

    echo "✅ Compatibility matrix generated"
    cat "$OUTPUT" | ${pkgs.jq}/bin/jq
  '';

  # Individual ecosystem tests
  test-with-claude-code = pkgs.writeShellScript "test-claude" ''
    SERVER=$1
    ${cell.packages.claude-code}/bin/claude --test-mcp "$SERVER" && echo "compatible"
  '';
}
```

**Compatibility Matrix Output:**
```json
{
  "git": {
    "claude_code": true,
    "gemini_cli": true,
    "qwen": true,
    "last_tested": "2025-01-15"
  },
  "postgres": {
    "claude_code": true,
    "gemini_cli": true,
    "qwen": false,
    "last_tested": "2025-01-15",
    "compatibility_notes": "Qwen requires async support"
  }
}
```

#### Registry Statistics

```nix
# lib.nix - Add statistics functions
{
  getStats = {
    total_servers = builtins.length (builtins.attrNames cell.data.allServers);
    npm_servers = builtins.length (builtins.filter (s: cell.data.allServers.${s}.providers ? npm) (builtins.attrNames cell.data.allServers));
    pip_servers = builtins.length (builtins.filter (s: cell.data.allServers.${s}.providers ? pip) (builtins.attrNames cell.data.allServers));
    nix_servers = builtins.length (builtins.filter (s: cell.data.allServers.${s}.providers ? nix) (builtins.attrNames cell.data.allServers));

    by_capability = builtins.mapAttrs (cap: _:
      builtins.length (cell.lib.findByCapability cap)
    ) {
      database = null;
      api = null;
      filesystem = null;
      cloud = null;
      ml = null;
    };

    by_ecosystem = {
      claude_code = builtins.length cell.data.compatibility.claude-code;
      gemini_cli = builtins.length cell.data.compatibility.gemini-cli;
      qwen = builtins.length cell.data.compatibility.qwen;
    };
  };
}
```

## Dependencies

- Inputs: `nixpkgs`
- External: npm (npx), pip (uvx), nix, gh (GitHub CLI)
- Consumes: None (foundational)
- Produces for: ALL agent cells, `routing`, `workspaces`

## Migration

Current `~/.config/comr/servers.json` → `cells/mcp/data.nix`

Migration tool provided in `runnables.nix`:
```bash
nix run .#mcp.runnables.migrate-servers-json
```

### Phase 5: Nushell Integration for Registry Management (Week 4, Days 4-7)

**Rationale:** MCP registry management involves heavy JSON operations (parsing server definitions, filtering by capabilities, merging registries, version comparison). These operations are Nushell's sweet spot - native structured data, clean pipelines, excellent table display.

**Commands to Convert:**
- `search` - Search registry by keyword/capability with formatted results
- `list-servers` - List servers with filtering and table display
- `sync-registry` - Fetch and merge from multiple sources (npm/pip/github)
- `check-updates` - Compare versions across registries
- `show-stats` - Display registry statistics

**Keep Bash:**
- `migrate-servers-json` - Simple file operations
- `test-compatibility` - External tool orchestration (calling different CLIs)

**runnables.nix - Nushell Version:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  writeNuApp = inputs.cells.lib.functions.writeNushellApplication;
  helpers = inputs.cells.lib.functions.includeHelpers;
in {
  # Nushell: Search registry with rich output
  search = writeNuApp {
    name = "comr-mcp-search";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        query: string                # Search query
        --capability: string         # Filter by capability
        --ecosystem: string          # Filter by ecosystem
        --provider: string           # Filter by provider (npm/pip/nix)
      ] {
        log "info" $"Searching MCP registry for: ($query)"

        # Load registry
        let registry_file = "~/.config/comr/server-registry.json"
        let registry = (safe-read-json $registry_file {})

        if ($registry | is-empty) {
          print "Registry not found. Run: comr mcp sync-registry"
          exit 1
        }

        let servers = $registry.servers

        # Search by query
        let query_lower = ($query | str downcase)
        let matches = (
          $servers
            | transpose name info
            | where {|row|
                let matches_keyword = ($row.info.keywords | any {|k| ($k | str contains $query_lower)})
                let matches_desc = ($row.info.description | str downcase | str contains $query_lower)
                let matches_name = ($row.name | str downcase | str contains $query_lower)
                $matches_keyword or $matches_desc or $matches_name
              }
        )

        # Apply filters
        let filtered = (
          $matches
            | where {|row|
                let cap_match = if $capability == null {
                  true
                } else {
                  $capability in $row.info.capabilities
                }

                let eco_match = if $ecosystem == null {
                  true
                } else {
                  $ecosystem in $row.info.ecosystems
                }

                let prov_match = if $provider == null {
                  true
                } else {
                  $provider in ($row.info.providers | columns)
                }

                $cap_match and $eco_match and $prov_match
              }
        )

        # Display results
        if ($filtered | is-empty) {
          print $"No servers found matching: ($query)"
          return
        }

        print $"🔍 Found ($filtered | length) server(s):"
        print ""

        $filtered
          | each {|row|
              {
                name: $row.name
                description: $row.info.description
                providers: ($row.info.providers | columns | str join ", ")
                capabilities: ($row.info.capabilities | str join ", ")
                ecosystems: ($row.info.ecosystems | str join ", ")
              }
            }
          | table -e
      }
    '';
  };

  # Nushell: List all servers with filtering
  list-servers = writeNuApp {
    name = "comr-mcp-list";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [
        --capability: string         # Filter by capability
        --ecosystem: string          # Filter by ecosystem
        --provider: string           # Filter by provider
        --format: string = "table"   # Output format: table, json, names
      ] {
        # Load registry
        let registry_file = "~/.config/comr/server-registry.json"
        let registry = (safe-read-json $registry_file {})

        if ($registry | is-empty) {
          print "Registry not found. Run: comr mcp sync-registry"
          exit 1
        }

        let servers = $registry.servers

        # Filter servers
        let filtered = (
          $servers
            | transpose name info
            | where {|row|
                let cap_match = if $capability == null {
                  true
                } else {
                  $capability in $row.info.capabilities
                }

                let eco_match = if $ecosystem == null {
                  true
                } else {
                  $ecosystem in $row.info.ecosystems
                }

                let prov_match = if $provider == null {
                  true
                } else {
                  $provider in ($row.info.providers | columns)
                }

                $cap_match and $eco_match and $prov_match
              }
        )

        # Format output
        match $format {
          "json" => {
            $filtered | to json
          }
          "names" => {
            $filtered | get name | each { print $in }
          }
          _ => {
            print $"📦 MCP Servers ($filtered | length):"
            print ""

            $filtered
              | each {|row|
                  {
                    name: $row.name
                    description: ($row.info.description | str substring 0..60)
                    providers: ($row.info.providers | columns | str join ", ")
                    ecosystems: ($row.info.ecosystems | str join ", ")
                  }
                }
              | table -e
          }
        }
      }
    '';
  };

  # Nushell: Sync registry from multiple sources
  sync-registry = writeNuApp {
    name = "comr-mcp-sync-registry";
    runtimeInputs = [pkgs.curl pkgs.gh];
    text = ''
      ${helpers}

      def main [
        --source: string = "all"  # all, npm, pip, github
      ] {
        print "🔄 Syncing MCP Server Registry..."
        print ""

        mut all_servers = {}

        # Sync from npm (@modelcontextprotocol packages)
        if $source in ["all" "npm"] {
          print "📦 Fetching npm packages..."
          let npm_servers = (fetch-npm-servers)
          $all_servers = ($all_servers | merge $npm_servers)
          print $"  ✓ Found ($npm_servers | length) npm servers"
        }

        # Sync from PyPI (mcp-server-* packages)
        if $source in ["all" "pip"] {
          print "🐍 Fetching pip packages..."
          let pip_servers = (fetch-pip-servers)
          $all_servers = ($all_servers | merge $pip_servers)
          print $"  ✓ Found ($pip_servers | length) pip servers"
        }

        # Sync from GitHub (official MCP servers repo)
        if $source in ["all" "github"] {
          print "🐙 Fetching GitHub repos..."
          let github_servers = (fetch-github-servers)
          $all_servers = ($all_servers | merge $github_servers)
          print $"  ✓ Found ($github_servers | length) GitHub servers"
        }

        # Save registry
        let output_dir = "~/.config/comr"
        ensure-dir $output_dir

        let registry = {
          version: "1.0"
          updated: (date now | date to-record)
          servers: $all_servers
        }

        $registry | to json | save -f ($output_dir + "/server-registry.json")

        print ""
        print $"✅ Registry synced successfully!"
        print $"   Total servers: ($all_servers | length)"

        # Show statistics
        show-sync-stats $all_servers
      }

      # Fetch npm servers
      def fetch-npm-servers [] {
        # Search npm for @modelcontextprotocol/* packages
        try {
          let search_result = (
            ^npm search @modelcontextprotocol --json
              | complete
              | get stdout
              | from json
          )

          $search_result
            | each {|pkg|
                let name = ($pkg.name | str replace "@modelcontextprotocol/server-" "")
                {
                  ($name): {
                    providers: {
                      npm: $pkg.name
                    }
                    description: $pkg.description
                    version: $pkg.version
                    keywords: ($pkg.keywords | default [])
                    capabilities: (infer-capabilities-from-name $name)
                    ecosystems: ["claude-code" "gemini-cli"]
                  }
                }
              }
            | reduce {|it, acc| $acc | merge $it} {}
        } catch {
          log "warning" "Failed to fetch npm servers"
          {}
        }
      }

      # Fetch pip servers
      def fetch-pip-servers [] {
        # Search PyPI for mcp-server-* packages
        try {
          let search_url = "https://pypi.org/search/?q=mcp-server"

          # Note: PyPI doesn't have a JSON search API, so we'd parse HTML or use a registry
          # For now, return known pip servers
          {
            docker: {
              providers: { pip: "mcp-server-docker" }
              description: "Docker container operations"
              capabilities: ["containers" "devops"]
              ecosystems: ["claude-code" "qwen"]
              keywords: ["docker" "containers"]
            }
            aws: {
              providers: { pip: "awslabs-mcp-server" }
              description: "AWS cloud operations"
              capabilities: ["cloud" "devops"]
              ecosystems: ["claude-code"]
              keywords: ["aws" "cloud"]
            }
          }
        } catch {
          log "warning" "Failed to fetch pip servers"
          {}
        }
      }

      # Fetch GitHub servers
      def fetch-github-servers [] {
        try {
          let gh_result = (
            ^gh api repos/modelcontextprotocol/servers/contents
              | complete
              | get stdout
              | from json
          )

          $gh_result
            | where type == "dir"
            | each {|item|
                let name = $item.name
                {
                  ($name): {
                    providers: {
                      nix: $"github:modelcontextprotocol/servers/main#($name)"
                    }
                    description: $"($name) server from official repo"
                    capabilities: (infer-capabilities-from-name $name)
                    ecosystems: ["claude-code" "gemini-cli"]
                    keywords: [$name]
                  }
                }
              }
            | reduce {|it, acc| $acc | merge $it} {}
        } catch {
          log "warning" "Failed to fetch GitHub servers"
          {}
        }
      }

      # Infer capabilities from server name
      def infer-capabilities-from-name [name: string] {
        let name_lower = ($name | str downcase)

        mut caps = []

        if ($name_lower | str contains "database") or ($name_lower in ["postgres" "sqlite" "mysql"]) {
          $caps = ($caps | append "database")
        }

        if ($name_lower | str contains "git") {
          $caps = ($caps | append "version-control")
        }

        if ($name_lower in ["github" "gitlab" "slack" "stripe"]) {
          $caps = ($caps | append "api")
        }

        if ($name_lower | str contains "filesystem") or ($name_lower == "fs") {
          $caps = ($caps | append "filesystem")
        }

        if ($name_lower in ["docker" "kubernetes" "aws" "gcp" "azure"]) {
          $caps = ($caps | append "cloud")
        }

        if ($name_lower | str contains "browser") or ($name_lower in ["playwright" "puppeteer"]) {
          $caps = ($caps | append "browser")
        }

        $caps
      }

      # Show sync statistics
      def show-sync-stats [servers: record] {
        print ""
        print "📊 Registry Statistics:"
        print "  ===================="

        # By provider
        let npm_count = (
          $servers
            | transpose name info
            | where "npm" in ($it.info.providers | columns)
            | length
        )

        let pip_count = (
          $servers
            | transpose name info
            | where "pip" in ($it.info.providers | columns)
            | length
        )

        let nix_count = (
          $servers
            | transpose name info
            | where "nix" in ($it.info.providers | columns)
            | length
        )

        print $"  npm packages: ($npm_count)"
        print $"  pip packages: ($pip_count)"
        print $"  nix flakes: ($nix_count)"
        print ""

        # Top capabilities
        print "  Top capabilities:"
        $servers
          | transpose name info
          | get info.capabilities
          | flatten
          | group-by
          | transpose capability servers
          | insert count {|row| $row.servers | length}
          | select capability count
          | sort-by -r count
          | first 5
          | each {|row| print $"    ($row.capability): ($row.count)"}
      }
    '';
  };

  # Nushell: Check for updates
  check-updates = writeNuApp {
    name = "comr-mcp-check-updates";
    runtimeInputs = [pkgs.curl];
    text = ''
      ${helpers}

      def main [
        --server: string  # Check specific server
      ] {
        print "🔍 Checking for MCP server updates..."
        print ""

        # Load registry
        let registry_file = "~/.config/comr/server-registry.json"
        let registry = (safe-read-json $registry_file {})

        if ($registry | is-empty) {
          print "Registry not found. Run: comr mcp sync-registry"
          exit 1
        }

        # Servers to check
        let servers_to_check = if $server == null {
          $registry.servers | transpose name info | get name
        } else {
          [$server]
        }

        # Check each server
        let updates = (
          $servers_to_check
            | each {|server_name|
                let server_info = ($registry.servers | get $server_name)

                # Check npm version
                let npm_update = if "npm" in ($server_info.providers | columns) {
                  check-npm-version $server_info.providers.npm ($server_info.version? | default "unknown")
                } else {
                  null
                }

                # Check pip version
                let pip_update = if "pip" in ($server_info.providers | columns) {
                  check-pip-version $server_info.providers.pip ($server_info.version? | default "unknown")
                } else {
                  null
                }

                {
                  server: $server_name
                  current: ($server_info.version? | default "unknown")
                  npm_latest: $npm_update
                  pip_latest: $pip_update
                  update_available: ($npm_update != null and $npm_update != ($server_info.version? | default "unknown"))
                }
              }
        )

        # Display results
        let with_updates = ($updates | where update_available)

        if ($with_updates | is-empty) {
          print "✅ All servers are up to date!"
        } else {
          print $"⚠️  ($with_updates | length) update(s) available:"
          print ""

          $with_updates
            | each {|row|
                {
                  server: $row.server
                  current: $row.current
                  latest: ($row.npm_latest? | default $row.pip_latest?)
                }
              }
            | table
        }

        print ""
        print "To update a server:"
        print "  nix run .#mcp.runnables.update-server -- <server-name> <version>"
      }

      # Check npm package version
      def check-npm-version [package: string, current: string] {
        try {
          let result = (
            ^npm view $package version
              | complete
              | get stdout
              | str trim
          )
          $result
        } catch {
          null
        }
      }

      # Check pip package version
      def check-pip-version [package: string, current: string] {
        try {
          let result = (
            ^curl -s $"https://pypi.org/pypi/($package)/json"
              | complete
              | get stdout
              | from json
              | get info.version
          )
          $result
        } catch {
          null
        }
      }
    '';
  };

  # Nushell: Show registry statistics
  show-stats = writeNuApp {
    name = "comr-mcp-stats";
    runtimeInputs = [];
    text = ''
      ${helpers}

      def main [] {
        print "📊 MCP Registry Statistics"
        print "=========================="
        print ""

        # Load registry
        let registry_file = "~/.config/comr/server-registry.json"
        let registry = (safe-read-json $registry_file {})

        if ($registry | is-empty) {
          print "Registry not found. Run: comr mcp sync-registry"
          exit 1
        }

        let servers = $registry.servers

        # Total servers
        let total = ($servers | length)
        print $"Total Servers: ($total)"
        print ""

        # By provider
        print "By Provider:"
        let server_list = ($servers | transpose name info)

        let npm_count = ($server_list | where "npm" in ($it.info.providers | columns) | length)
        let pip_count = ($server_list | where "pip" in ($it.info.providers | columns) | length)
        let nix_count = ($server_list | where "nix" in ($it.info.providers | columns) | length)

        [
          {provider: "npm" count: $npm_count}
          {provider: "pip" count: $pip_count}
          {provider: "nix" count: $nix_count}
        ] | table
        print ""

        # By ecosystem
        print "By Ecosystem:"
        let claude_count = (
          $server_list
            | where "claude-code" in $it.info.ecosystems
            | length
        )
        let gemini_count = (
          $server_list
            | where "gemini-cli" in $it.info.ecosystems
            | length
        )
        let qwen_count = (
          $server_list
            | where "qwen" in $it.info.ecosystems
            | length
        )

        [
          {ecosystem: "claude-code" count: $claude_count}
          {ecosystem: "gemini-cli" count: $gemini_count}
          {ecosystem: "qwen" count: $qwen_count}
        ] | table
        print ""

        # Top capabilities
        print "Top 10 Capabilities:"
        $server_list
          | get info.capabilities
          | flatten
          | group-by
          | transpose capability servers
          | insert count {|row| $row.servers | length}
          | select capability count
          | sort-by -r count
          | first 10
          | table
        print ""

        # Registry metadata
        print $"Last Updated: ($registry.updated)"
        print $"Registry Version: ($registry.version)"
      }
    '';
  };

  # Keep bash for simple operations
  migrate-servers-json = pkgs.writeShellScriptBin "comr-mcp-migrate" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Simple file copy/transformation
    LEGACY_FILE="$HOME/.config/comr/servers.json"
    NEW_FILE="$HOME/.config/comr/server-registry.json"

    if [[ ! -f "$LEGACY_FILE" ]]; then
      echo "No legacy servers.json found"
      exit 0
    fi

    echo "🔄 Migrating servers.json to new registry format..."

    # Transform legacy format to new format
    ${pkgs.jq}/bin/jq '{
      version: "1.0",
      updated: (now | todate),
      servers: .
    }' "$LEGACY_FILE" > "$NEW_FILE"

    echo "✅ Migration complete"
  '';

  # Keep bash for external tool orchestration
  test-compatibility = pkgs.writeShellScriptBin "comr-mcp-test-compatibility" ''
    # ... same as before (external tool orchestration) ...
  '';

  update-server = pkgs.writeShellScriptBin "comr-mcp-update-server" ''
    # ... same as before ...
  '';
}
```

**Benefits of Nushell for MCP:**

1. **Native JSON Parsing**: Registry is JSON-heavy - `from json` is built-in, no more jq
2. **Filtering & Searching**: Complex multi-field searches with clean where clauses
3. **Table Display**: Beautiful server lists with `| table`
4. **Data Merging**: Multiple registries merged with `merge` instead of jq
5. **Aggregation**: Group-by for statistics (capabilities, providers)
6. **Error Handling**: try/catch instead of bash conditionals
7. **Type Safety**: Null checks, field validation

**Example Output:**

```
$ comr mcp search postgres
🔍 Found 2 server(s):

╭──────────┬──────────────────────────┬───────────┬──────────────────┬────────────────────╮
│ name     │ description              │ providers │ capabilities     │ ecosystems         │
├──────────┼──────────────────────────┼───────────┼──────────────────┼────────────────────┤
│ postgres │ PostgreSQL database ops  │ npm       │ database, sql    │ claude-code, gemini│
│ pgvector │ Postgres vector search   │ nix       │ database, ml     │ claude-code        │
╰──────────┴──────────────────────────┴───────────┴──────────────────┴────────────────────╯

$ comr mcp list --capability database --format table
📦 MCP Servers (15):

╭──────────────┬──────────────────────────┬───────────┬────────────────────╮
│ name         │ description              │ providers │ ecosystems         │
├──────────────┼──────────────────────────┼───────────┼────────────────────┤
│ postgres     │ PostgreSQL operations    │ npm       │ claude-code, gemini│
│ sqlite       │ SQLite operations        │ npm       │ claude-code        │
│ mysql        │ MySQL operations         │ npm       │ claude-code, gemini│
╰──────────────┴──────────────────────────┴───────────┴────────────────────╯

$ comr mcp sync-registry --source npm
🔄 Syncing MCP Server Registry...

📦 Fetching npm packages...
  ✓ Found 45 npm servers

✅ Registry synced successfully!
   Total servers: 45

📊 Registry Statistics:
  ====================
  npm packages: 45
  pip packages: 0
  nix flakes: 0

  Top capabilities:
    api: 12
    database: 8
    filesystem: 5
    browser: 3
    cloud: 3

$ comr mcp check-updates
🔍 Checking for MCP server updates...

⚠️  3 update(s) available:

╭──────────┬─────────┬────────╮
│ server   │ current │ latest │
├──────────┼─────────┼────────┤
│ git      │ 1.2.0   │ 1.3.0  │
│ postgres │ 0.5.0   │ 0.6.1  │
│ github   │ 0.8.0   │ 1.0.0  │
╰──────────┴─────────┴────────╯

To update a server:
  nix run .#mcp.runnables.update-server -- <server-name> <version>

$ comr mcp stats
📊 MCP Registry Statistics
==========================

Total Servers: 87

By Provider:
╭──────────┬───────╮
│ provider │ count │
├──────────┼───────┤
│ npm      │ 52    │
│ pip      │ 18    │
│ nix      │ 17    │
╰──────────┴───────╯

By Ecosystem:
╭─────────────┬───────╮
│ ecosystem   │ count │
├─────────────┼───────┤
│ claude-code │ 75    │
│ gemini-cli  │ 45    │
│ qwen        │ 12    │
╰─────────────┴───────╯

Top 10 Capabilities:
╭───────────────┬───────╮
│ capability    │ count │
├───────────────┼───────┤
│ api           │ 25    │
│ database      │ 15    │
│ filesystem    │ 12    │
│ cloud         │ 10    │
│ browser       │ 8     │
╰───────────────┴───────╯
```

**When to Use Each:**

**Use Nushell:**
- ✅ Registry search/filtering (`search`, `list-servers`)
- ✅ Data fetching & merging (`sync-registry`)
- ✅ Version comparison (`check-updates`)
- ✅ Statistics & aggregation (`show-stats`)
- ✅ Table display

**Keep Bash:**
- ✅ Simple file operations (`migrate-servers-json`)
- ✅ External tool orchestration (`test-compatibility`)
- ✅ Complex process management

## Success Criteria

- [ ] 100+ servers catalogued (30 core + 70+ extended)
- [ ] All three providers supported (npm, pip, nix)
- [ ] Discovery API works
- [ ] Compatibility matrix accurate
- [ ] All current servers migrated
- [ ] Documentation complete
- [ ] Auto-sync mechanism functional
- [ ] Version management implemented
- [ ] Compatibility testing automated
- [ ] Registry statistics available
- [ ] **Nushell commands (search, list, sync, check-updates, stats) functional**
- [ ] **Rich table formatting working**
- [ ] **Multi-source registry merging accurate**
- [ ] **Version checking against npm/PyPI working**
