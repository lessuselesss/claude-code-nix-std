# Director vs Nix Flake Apps: Feature Comparison

## Director's Core Features → Nix Equivalents

| Director Feature | Nix Flake Implementation | Status |
|-----------------|-------------------------|--------|
| **Workspace Management** | Flake apps with custom configs | ✅ Better |
| **MCP Server Routing** | Nix overlays + package selection | ✅ Better |
| **Tool Discovery** | `nix flake show` + metadata | ✅ Native |
| **Security Sandbox** | Nix derivations (isolated builds) | ✅ Better |
| **Portable Config** | `flake.lock` (reproducible) | ✅ Better |
| **Version Pinning** | Flake inputs with hash locks | ✅ Better |
| **Multi-Client Support** | CLAUDE_SETTINGS env var | ✅ Simpler |
| **Tool Filtering** | comr semantic routing | ✅ Smarter |
| **Custom Prompts** | Nix string interpolation | ✅ Native |
| **HTTP/stdio Support** | Package types (flake/package/executable) | ✅ Done |

## Why Nix Flakes Are Superior

### 1. **Workspace Management**

**Director (YAML):**
```yaml
workspaces:
  python-dev:
    servers:
      sqlite:
        type: stdio
        command: npx -y mcp-sqlite
```

**Nix (Flake Apps):**
```nix
{
  apps.x86_64-linux = {
    python-dev = {
      type = "app";
      program = pkgs.writeShellScript "python-dev" ''
        CLAUDE_SETTINGS=$(jq -n '{
          mcpServers: {
            sqlite: {command: "npx", args: ["-y", "mcp-sqlite"]},
            filesystem: {command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem"]}
          }
        }' | mktemp)
        claude -p "$@"
      '';
    };
  };
}
```

**Run:** `nix run .#python-dev "analyze database schema"`

**Nix Advantages:**
- ✅ Type-safe configuration (Nix validates at build time)
- ✅ Reproducible (flake.lock ensures exact versions)
- ✅ No runtime YAML parsing errors
- ✅ Can include actual packages, not just commands

### 2. **Server Discovery & Routing**

**Director:**
- Runtime proxy that routes requests
- YAML config parsed on every run
- Manual tool listing: `mcp list-tools`

**Nix + comr:**
- Build-time server composition
- Semantic LLM routing (smarter than static config)
- Auto-discovery from registry
- Zero runtime overhead

### 3. **Security & Isolation**

**Director:**
- Server sandboxing via proxy
- Tool filtering per workspace
- Manual allowlist/denylist

**Nix:**
- **Derivation-level isolation** (every package builds in sandbox)
- **Content-addressed storage** (can't tamper with /nix/store)
- **Cryptographic verification** (flake inputs have sha256 hashes)
- **No privilege escalation** (builds run as unprivileged user)

**Director can't match this** - Nix's security model is at the OS level.

### 4. **Portability & Reproducibility**

**Director:**
```yaml
# workspace.yaml - hopes dependencies exist on system
servers:
  postgres:
    command: npx -y @modelcontextprotocol/server-postgres
```

**Nix:**
```nix
# flake.nix - guarantees exact versions
inputs.nixpkgs.url = "github:nixos/nixpkgs?rev=abc123";
# Anyone running this gets EXACT same nodejs, npx, packages
```

**Nix Advantage:** `flake.lock` is a cryptographic guarantee. Director's YAML is just a suggestion.

### 5. **Tool Prefixing & Namespacing**

**Director:**
```yaml
servers:
  local-fs:
    type: stdio
    command: npx @modelcontextprotocol/server-filesystem
    tools:
      prefix: local_
```

**Nix:**
```nix
# Just use different server names - problem solved
mcpServers = {
  local-filesystem = { ... };
  remote-filesystem = { ... };
};
```

**Nix Advantage:** No need for prefixing hack - proper namespacing via derivation names.

---

## Nix Flake Apps Implementation

### Architecture

```
┌─────────────────────────────────────────────────────┐
│  User: nix run .#python-dev "analyze code"          │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Flake App: python-dev                              │
│  • Builds temp config with selected MCP servers     │
│  • Sets CLAUDE_SETTINGS env var                     │
│  • Executes claude with workspace context           │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  Claude Code loads ONLY selected servers:           │
│  • sqlite (via npx)                                 │
│  • filesystem (via npx)                             │
│  • git (always included)                            │
└─────────────────────────────────────────────────────┘
```

### Example Implementation

```nix
# ~/Projects/Flakes/comr-flake/flake.nix
{
  description = "comr + workspace apps";

  outputs = { self, nixpkgs }: {
    apps.x86_64-linux = {
      # Default comr
      default = {
        type = "app";
        program = "${self.packages.x86_64-linux.comr}/bin/comr";
      };

      # Python workspace
      python-dev = {
        type = "app";
        program = pkgs.writeShellScript "python-dev-workspace" ''
          WORKSPACE_CONFIG=$(mktemp)
          cat > "$WORKSPACE_CONFIG" <<'EOF'
          {
            "mcpServers": {
              "sqlite": {"command": "npx", "args": ["-y", "mcp-sqlite"]},
              "filesystem": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem"]},
              "git": {"command": "uvx", "args": ["mcp-server-git"]}
            }
          }
          EOF

          CLAUDE_SETTINGS="$WORKSPACE_CONFIG" claude -p "$@"
          rm "$WORKSPACE_CONFIG"
        '';
      };

      # Web dev workspace
      web-dev = {
        type = "app";
        program = pkgs.writeShellScript "web-dev-workspace" ''
          WORKSPACE_CONFIG=$(mktemp)
          cat > "$WORKSPACE_CONFIG" <<'EOF'
          {
            "mcpServers": {
              "playwright": {"command": "nix", "args": ["run", "github:BeehiveInnovations/playwright-mcp", "--"]},
              "github": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"]},
              "brave-search": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-brave-search"]}
            }
          }
          EOF

          CLAUDE_SETTINGS="$WORKSPACE_CONFIG" claude -p "$@"
          rm "$WORKSPACE_CONFIG"
        '';
      };

      # Data analysis workspace
      data-analysis = {
        type = "app";
        program = pkgs.writeShellScript "data-workspace" ''
          WORKSPACE_CONFIG=$(mktemp)
          cat > "$WORKSPACE_CONFIG" <<'EOF'
          {
            "mcpServers": {
              "postgres": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-postgres"]},
              "sqlite": {"command": "npx", "args": ["-y", "mcp-sqlite"]},
              "filesystem": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem"]},
              "git": {"command": "uvx", "args": ["mcp-server-git"]}
            }
          }
          EOF

          CLAUDE_SETTINGS="$WORKSPACE_CONFIG" claude -p "$@"
          rm "$WORKSPACE_CONFIG"
        '';
      };
    };
  };
}
```

### Usage

```bash
# Python development
nix run .#python-dev "analyze this Python project"

# Web development
nix run .#web-dev "test the login flow with playwright"

# Data analysis
nix run .#data-analysis "query the users table in postgres"

# Default (comr semantic routing)
nix run . "commit my changes"
```

### Advanced: Workspace Generator

```nix
# Helper function to create workspaces
mkWorkspace = name: servers: prompts: {
  type = "app";
  program = pkgs.writeShellScript "${name}-workspace" ''
    WORKSPACE_CONFIG=$(mktemp)

    # Base servers
    cat > "$WORKSPACE_CONFIG" <<'EOF'
    {"mcpServers": ${builtins.toJSON servers}}
    EOF

    # Custom prompts
    ${lib.optionalString (prompts != []) ''
      CUSTOM_PROMPTS="${lib.concatMapStringsSep "\n" (p: p.content) prompts}"
      export CLAUDE_CUSTOM_PROMPTS="$CUSTOM_PROMPTS"
    ''}

    CLAUDE_SETTINGS="$WORKSPACE_CONFIG" claude -p "$@"
    rm "$WORKSPACE_CONFIG"
  '';
};

apps.x86_64-linux = {
  python-dev = mkWorkspace "python-dev"
    {
      sqlite = {command = "npx"; args = ["-y" "mcp-sqlite"];};
      filesystem = {command = "npx"; args = ["-y" "@modelcontextprotocol/server-filesystem"];};
    }
    [
      {name = "python-expert"; content = "You are a Python expert. Focus on type hints, async/await, and best practices.";}
    ];
};
```

---

## Migration Path: Director → Nix

### Step 1: Convert YAML to Nix

**Director workspace.yaml:**
```yaml
workspaces:
  my-project:
    description: "Project workspace"
    servers:
      github:
        type: stdio
        command: npx
        args: ["-y", "@modelcontextprotocol/server-github"]
      filesystem:
        type: stdio
        command: npx
        args: ["-y", "@modelcontextprotocol/server-filesystem"]
```

**Nix equivalent:**
```nix
apps.x86_64-linux.my-project = {
  type = "app";
  program = pkgs.writeShellScript "my-project" ''
    CLAUDE_SETTINGS=$(jq -n '{
      mcpServers: {
        github: {command: "npx", args: ["-y", "@modelcontextprotocol/server-github"]},
        filesystem: {command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem"]}
      }
    }') claude -p "$@"
  '';
};
```

### Step 2: Add to System Flake

```nix
# ~/Projects/Flakes/nixos-config-with-mcp/flake.nix
{
  inputs.comr-workspaces = {
    url = "path:/home/lessuseless/Projects/Flakes/comr-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Make apps available system-wide
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "workspace" ''
      nix run ${inputs.comr-workspaces}#"$@"
    '')
  ];
}
```

**Usage:**
```bash
workspace python-dev "analyze code"
workspace web-dev "test UI"
workspace data-analysis "query database"
```

---

## Advantages Over Director

### 1. **No Runtime Dependencies**
- Director: Requires Node.js, director CLI, config parser
- Nix: Everything in /nix/store, no global installs

### 2. **Atomic Updates**
- Director: YAML changes affect all users immediately
- Nix: `flake.lock` pins versions, update when ready

### 3. **Offline Support**
- Director: Needs network to fetch MCP servers
- Nix: Once built, works offline (cached in /nix/store)

### 4. **Type Safety**
- Director: YAML parsing errors at runtime
- Nix: Validated at build time, fails early

### 5. **Integration**
- Director: Separate tool, separate config
- Nix: Part of your system flake, unified config

---

## Conclusion

Director is a good concept, but **Nix flakes already provide everything it does, plus:**

- ✅ Cryptographic reproducibility (flake.lock)
- ✅ Build-time validation (no runtime YAML errors)
- ✅ OS-level security (Nix sandbox)
- ✅ Offline support (Nix store cache)
- ✅ Atomic rollbacks (Nix generations)
- ✅ Native tool discovery (`nix flake show`)

**comr + Nix apps = Director, but better** 🚀

We already have the foundation - just need to add workspace apps to comr flake!
