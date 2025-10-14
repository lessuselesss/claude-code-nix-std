# Gemini CLI Agent Cell

## Purpose

Integrate Gemini CLI ecosystem with 70+ extensions for services like Stripe, Postman, Shopify, Figma, etc. Provide interface to Google's AI-powered command-line agent with extension bundling (MCP servers + context + commands).

## Key Features

- 70+ official extensions (Stripe, Postman, Shopify, Figma, Dynatrace, Snyk, Elastic)
- Extension bundling: MCP servers + context files + custom commands
- Discovery via geminicli.work/extensions
- Install directly from GitHub repos

## Three-Layer API

**Layer 1:**
```nix
geminiCli.useExtension "stripe" "create subscription for user@example.com"
geminiCli.useExtension "figma" "export design assets"
```

**Layer 2:**
```nix
geminiCli.buildContext {
  extensions = ["stripe" "postman"];
  mcpServers = ["additional-server"];
  contextFiles = ["./docs"];
}
```

**Layer 3:**
```nix
geminiCli.command {
  config = { extensions = [...]; };
  prompt = "task";
}
```

## Files

```
cells/agents/gemini-cli/
├── CLAUDE.md
├── lib.nix          # Gemini CLI API
├── packages.nix     # gemini CLI binary
├── data.nix         # Extension registry (70+)
├── functions.nix    # Extension loaders
└── runnables.nix    # Extension contexts
```

## Implementation Plan

### Phase 1: Extension Registry (Week 3, Days 1-2)

**data.nix:**
```nix
{
  extensions = {
    stripe = {
      repo = "https://github.com/stripe/gemini-cli-extension";
      mcp = true;
      commands = ["payments" "subscriptions" "refunds"];
      context = "stripe-api-docs";
    };
    postman = {
      repo = "https://github.com/postman/gemini-extension";
      mcp = true;
      commands = ["collections" "environments"];
    };
    shopify = {...};
    figma = {...};
    # ... 70+ extensions
  };
}
```

### Phase 2: Extension Loader (Week 3, Days 3-4)

**lib.nix:**
```nix
{
  useExtension = name: task: let
    ext = cell.data.extensions.${name};
    config = cell.functions.loadExtension ext;
  in cell.functions.executeGemini config task;

  buildContext = { extensions, mcpServers ? [], contextFiles ? [] }:
    cell.functions.bundleExtensions extensions mcpServers contextFiles;
}
```

### Phase 3: Gemini CLI Package (Week 3, Days 5-7)

**packages.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # Gemini CLI binary
  # NOTE: Gemini CLI availability depends on Google's distribution method
  # Check https://geminicli.work for official releases

  gemini-cli = pkgs.stdenv.mkDerivation rec {
    pname = "gemini-cli";
    version = "1.0.0";  # Update to actual version

    # Option 1: Binary distribution (if Google provides)
    src = pkgs.fetchurl {
      url = "https://dl.google.com/gemini-cli/gemini-cli-${version}-linux-x86_64.tar.gz";
      sha256 = "0000000000000000000000000000000000000000000000000000";  # Update with actual hash
    };

    # Option 2: Build from source (if open-sourced)
    # src = pkgs.fetchFromGitHub {
    #   owner = "google";
    #   repo = "gemini-cli";
    #   rev = "v${version}";
    #   sha256 = "...";
    # };

    # If closed-source binary, mark as unfree
    meta = with pkgs.lib; {
      description = "Google Gemini CLI agent with 70+ extensions";
      homepage = "https://geminicli.work";
      license = licenses.unfree;  # Adjust based on actual license
      platforms = platforms.linux ++ platforms.darwin;
      maintainers = [];
    };

    # Binary installation
    installPhase = ''
      mkdir -p $out/bin
      cp gemini $out/bin/gemini-cli
      chmod +x $out/bin/gemini-cli

      # Create wrapper with environment setup
      cat > $out/bin/gemini <<EOF
      #!/usr/bin/env bash
      # Gemini CLI wrapper with Nix environment
      export GEMINI_HOME="\''${GEMINI_HOME:-\$HOME/.config/gemini}"
      export GEMINI_EXTENSIONS_DIR="\$GEMINI_HOME/extensions"
      mkdir -p "\$GEMINI_EXTENSIONS_DIR"

      # Ensure GEMINI_API_KEY is set
      if [[ -z "\$GEMINI_API_KEY" ]]; then
        echo "Error: GEMINI_API_KEY environment variable not set" >&2
        exit 1
      fi

      exec $out/bin/gemini-cli "\$@"
      EOF
      chmod +x $out/bin/gemini
    '';

    # For Go binaries (if source build)
    # nativeBuildInputs = [ pkgs.go ];
    # buildPhase = ''
    #   go build -o gemini ./cmd/gemini
    # '';

    # For Node.js based CLI (alternative)
    # nativeBuildInputs = [ pkgs.nodejs pkgs.nodePackages.npm ];
    # buildPhase = ''
    #   npm install
    #   npm run build
    # '';
  };

  # Wrapper with extension management
  gemini-with-extensions = extensions: pkgs.writeShellScriptBin "gemini-ext" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Pre-load extensions
    EXTENSION_FLAGS=""
    ${builtins.concatStringsSep "\n" (builtins.map (ext: ''
      EXTENSION_FLAGS="$EXTENSION_FLAGS --extension ${ext}"
    '') extensions)}

    # Execute Gemini CLI with extensions
    ${gemini-cli}/bin/gemini $EXTENSION_FLAGS "$@"
  '';

  # Development version (for testing)
  gemini-cli-dev = gemini-cli.overrideAttrs (oldAttrs: {
    version = "dev";
    # Use latest commit or local checkout
    src = /path/to/local/gemini-cli;  # For local development
  });
}
```

**Handling Closed-Source Distribution:**

If Gemini CLI is closed-source, users must:
1. Allow unfree packages in Nix configuration:
```nix
# nixpkgs config
nixpkgs.config.allowUnfree = true;
# OR allow specific package
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) ["gemini-cli"];
```

2. Manual installation fallback:
```bash
# If Nix package unavailable, use system installation
curl -L https://geminicli.work/install.sh | sh
export PATH="$HOME/.gemini/bin:$PATH"
```

**Verification:**
```bash
# Test Gemini CLI package
nix build .#agents.gemini-cli.packages.gemini-cli
./result/bin/gemini --version

# Test with API key
GEMINI_API_KEY="..." nix run .#agents.gemini-cli.packages.gemini-cli -- "Hello"
```

## Security Model

### Threat Vectors

Gemini CLI extensions have elevated privileges:
- **API Access**: Full access to third-party services (Stripe, Shopify, Figma)
- **Credentials**: Requires API keys for 70+ services
- **Code Execution**: Extensions execute arbitrary code
- **Network Access**: Unrestricted internet connectivity
- **MCP Servers**: Bundle and execute MCP servers

### Security Layers

#### **1. Extension Verification**

```nix
# functions.nix - Verify extension authenticity
verifyExtension = extension:
  let
    # Official extensions are hosted under trusted GitHub orgs
    trustedOrgs = ["stripe" "postman" "shopify" "figma" "google"];

    # Extract GitHub org from repo URL
    org = builtins.elemAt (builtins.split "/" extension.repo) 2;

    isTrusted = builtins.elem org trustedOrgs;

    # Verify extension signature (if provided)
    hasSignature = builtins.pathExists "${extension.repo}/.signature";
    signatureValid = if hasSignature
                     then verifyGitHubSignature extension.repo
                     else false;
  in {
    trusted = isTrusted;
    signed = signatureValid;
    requires_consent = !(isTrusted || signatureValid);
  };
```

**Extension Trust Levels:**
- **Official**: From trusted orgs (Stripe, Shopify, Google, etc.) - Auto-trusted
- **Signed**: GPG-signed extensions from verified authors - User consent
- **Community**: Unsigned community extensions - Explicit user consent + review

#### **2. API Key Management**

**Per-Extension API Keys:**
```nix
# data.nix - Define required API keys per extension
extensionApiKeys = {
  stripe = ["STRIPE_API_KEY" "STRIPE_PUBLISHABLE_KEY"];
  shopify = ["SHOPIFY_API_KEY" "SHOPIFY_STORE_URL"];
  figma = ["FIGMA_ACCESS_TOKEN"];
  postman = ["POSTMAN_API_KEY"];
  github = ["GITHUB_TOKEN"];
  slack = ["SLACK_TOKEN"];
  # ... 70+ extensions
};

# functions.nix - Validate API keys before extension load
validateExtensionKeys = extension:
  let
    requiredKeys = extensionApiKeys.${extension} or [];
    missingKeys = builtins.filter (k: builtins.getEnv k == "") requiredKeys;
  in
    if missingKeys != []
    then throw "Extension ${extension} requires: ${builtins.concatStringsSep ", " missingKeys}"
    else true;
```

**Key Isolation:**
```bash
# Only pass required keys to extension, not all environment variables
executeExtension() {
  local EXTENSION=$1
  local TASK=$2

  # Build isolated environment with only required keys
  ENV_VARS=""
  for KEY in $(get_required_keys "$EXTENSION"); do
    if [[ -n "${!KEY}" ]]; then
      ENV_VARS="$ENV_VARS $KEY=${!KEY}"
    fi
  done

  # Execute with minimal environment
  env -i $ENV_VARS ${gemini-cli}/bin/gemini --extension "$EXTENSION" "$TASK"
}
```

**Secure Key Storage:**
```bash
# Recommended: Use system keyring instead of environment variables
# Store keys securely
secret-tool store --label="Stripe API Key" service stripe key api-key

# Retrieve for extension execution
STRIPE_API_KEY=$(secret-tool lookup service stripe key api-key)
```

#### **3. Extension Sandboxing**

**Network Restrictions:**
```nix
# Only allow network access to extension's declared domains
mkSandboxedExtension = extension:
  let
    allowedDomains = extension.allowed_domains or [];
    domainRules = builtins.concatStringsSep "," allowedDomains;
  in
    pkgs.writeShellScript "sandboxed-${extension.name}" ''
      # Use firejail or bubblewrap to restrict network
      ${pkgs.firejail}/bin/firejail \
        --net=none \
        --whitelist=${domainRules} \
        ${gemini-cli}/bin/gemini --extension ${extension.name} "$@"
    '';
```

**Filesystem Restrictions:**
```bash
# Restrict extension filesystem access
bwrap \
  --ro-bind /nix/store /nix/store \
  --bind $PWD workspace \
  --tmpfs /tmp \
  --tmpfs $HOME/.config/gemini/extensions/${EXTENSION} \
  --unshare-all \
  --share-net \
  --die-with-parent \
  ${gemini-cli}/bin/gemini --extension "$EXTENSION" "$TASK"
```

#### **4. MCP Server Bundling Security**

Extensions often bundle MCP servers. Verify these are safe:

```nix
# functions.nix - Scan extension's bundled MCP servers
scanExtensionMcpServers = extension:
  let
    # Extract MCP servers from extension manifest
    mcpServers = extension.mcp_servers or [];

    # Validate each server against MCP registry
    validated = builtins.map (server:
      inputs.cells.mcp.lib.validateServer server
    ) mcpServers;

    # Check for vulnerabilities
    vulnerabilities = builtins.map (server:
      inputs.cells.marketplaces.lib.scanDependencies server
    ) mcpServers;

    criticalIssues = builtins.filter (v: v.severity == "critical") vulnerabilities;
  in
    if criticalIssues != []
    then throw "Extension ${extension.name} has critical vulnerabilities in bundled MCP servers"
    else validated;
```

### Security Configuration

**data.nix:**
```nix
{
  security = {
    # Extension verification
    extension_verification = {
      enable = true;
      trusted_orgs = ["stripe" "postman" "shopify" "figma" "google" "microsoft"];
      require_signatures = false;  # Warn but don't block unsigned
      user_consent_for_community = true;
    };

    # API key protection
    api_keys = {
      validate_before_load = true;
      per_extension_isolation = true;
      storage = "keyring";  # "environment" | "keyring" | "age-encrypted"
      rotate_on_compromise = true;
    };

    # Extension sandboxing
    sandbox = {
      enable = true;
      restrict_network = false;  # Extensions need network for APIs
      restrict_filesystem = true;
      max_memory_mb = 2048;
      timeout_seconds = 600;
    };

    # MCP server bundling
    bundled_mcp_servers = {
      scan_dependencies = true;
      validate_against_registry = true;
      block_critical_vulnerabilities = true;
    };
  };
}
```

### Security Best Practices

**For Users:**
1. Only install extensions from official sources (Stripe, Shopify, etc.)
2. Review extension source code before installation
3. Use separate API keys for different environments (dev/prod)
4. Rotate API keys regularly
5. Use system keyring instead of environment variables for sensitive keys
6. Monitor extension network activity (use firewall logs)

**For Extension Developers:**
1. GPG-sign extensions for user trust
2. Declare minimum required API scopes
3. Document all network domains accessed
4. Bundle only verified MCP servers
5. Follow principle of least privilege
6. Provide security audit reports

## Dependencies

- Inputs: `nixpkgs`, `cells.mcp`, `cells.llm`
- External: Gemini CLI binary, `GEMINI_API_KEY`
- Consumes: `mcp` cell
- Produces for: `workspaces`, `orchestrators`

## Success Criteria

- [ ] 70+ extensions catalogued
- [ ] Extension loading works
- [ ] MCP server bundling functional
- [ ] Context injection works
- [ ] Documentation complete
- [ ] Gemini CLI binary packaged (or manual install documented)
- [ ] Unfree license handling works
- [ ] Extension verification functional
- [ ] API key isolation per extension
- [ ] Extension sandboxing enforced
- [ ] Bundled MCP server scanning works
