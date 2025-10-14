# Marketplaces Cell - Plugin Discovery & Installation

## Purpose

Discover and install plugins from multiple marketplaces (Claude Code plugins, Gemini CLI extensions, community repos). Unified interface for 100+ plugins across ecosystems.

## Key Features

- **Multi-Marketplace**: Claude Code, Gemini CLI, Every, community
- **Discovery**: Search across all marketplaces
- **Installation**: One-command plugin install
- **Caching**: 24h TTL for marketplace data
- **Fuzzy Matching**: Find plugins by partial name
- **Security**: Plugin verification, sandboxing, user consent

## Security Model

### Threat Model

Marketplace plugins execute arbitrary code with access to:
- Filesystem (workspace directory)
- MCP servers (git, database, APIs)
- Environment variables (API keys)
- Network (external services)

**Attack Vectors:**
1. **Malicious Plugins**: Attacker publishes plugin that steals API keys or exfiltrates code
2. **Supply Chain**: Legitimate plugin compromised by dependency attack
3. **Social Engineering**: Plugin with convincing name/description masks malicious behavior
4. **Privilege Escalation**: Plugin escapes sandbox to access system resources

### Security Layers

#### **Layer 1: Source Verification**

```nix
# functions.nix - Verify plugin source
verifyPluginSource = url:
  let
    # Extract repository info
    repo = parseGitHubUrl url;

    # Check against allowlist
    isTrusted = builtins.elem repo.owner trustedPublishers;

    # For untrusted sources, require user consent
    if !isTrusted then requireUserConsent repo else {};
  in
    if isTrusted
    then { verified = true; trust_level = "high"; }
    else { verified = false; trust_level = "untrusted"; };
```

**Trusted Publishers:**
- `EveryInc/*` - Every marketplace (official)
- `anthropics/*` - Anthropic official plugins
- `google/*` - Google official plugins
- User-configured allowlist in `~/.config/comr/trusted-publishers.json`

#### **Layer 2: Dependency Scanning**

```nix
# functions.nix - Scan plugin dependencies
scanDependencies = pluginPath:
  let
    # Extract package.json / pyproject.toml / go.mod
    manifest = detectManifest pluginPath;

    # Check against CVE database
    vulnerabilities = pkgs.runCommand "scan-deps" {
      buildInputs = [ pkgs.trivy pkgs.osv-scanner ];
    } ''
      cd ${pluginPath}
      trivy fs --severity HIGH,CRITICAL . > $out/trivy.json
      osv-scanner --format json . > $out/osv.json
    '';
  in
    parseVulnerabilities vulnerabilities;
```

**Vulnerability Actions:**
- **Critical**: Block installation, warn user
- **High**: Warn user, require explicit consent
- **Medium/Low**: Log, allow installation

#### **Layer 3: Sandboxing**

**Nix Sandbox (Build-time):**
```nix
# packages.nix - Sandboxed plugin build
mkSandboxedPlugin = plugin:
  pkgs.runCommand "plugin-${plugin.name}" {
    # Restrict network access during build
    __noChroot = false;

    # Isolated build environment
    buildInputs = [ /* minimal dependencies */ ];
  } ''
    # Build plugin in isolated environment
    cp -r ${plugin.source} $out
    # No network, no user home, no system access
  '';
```

**Runtime Sandbox (Execution):**
```bash
# Use bubblewrap for runtime sandboxing
bwrap \
  --ro-bind /nix/store /nix/store \
  --bind $PWD workspace \
  --tmpfs /tmp \
  --unshare-all \
  --share-net \  # Allow network for API calls
  --die-with-parent \
  --new-session \
  ${plugin}/bin/plugin-command
```

**Sandbox Restrictions:**
- **Filesystem**: Read-only Nix store, read-write workspace directory only
- **Network**: Allowed (needed for MCP/API calls)
- **Process**: Cannot spawn shells, limited to plugin process tree
- **Environment**: Only explicitly passed variables (no $HOME, no system paths)

#### **Layer 4: User Consent Workflow**

**First Installation:**
```
📦 Plugin: code-simplicity-reviewer
📝 Source: https://github.com/EveryInc/every-marketplace
⚠️  Trust Level: UNTRUSTED (not in allowlist)

This plugin requests access to:
  ✓ Workspace files (read-only)
  ✓ Git MCP server
  ✓ Sequential-thinking MCP server
  ✗ Filesystem writes (denied by sandbox)

Permissions:
  - Read code in current directory
  - Access git history
  - Make LLM calls for analysis

Security Scan Results:
  ✓ No critical vulnerabilities
  ⚠️  1 medium severity dependency issue

Do you want to proceed? [y/N/always/never]
  y - Install once
  always - Add to trusted publishers
  never - Block this plugin permanently
```

**Consent Storage:**
```json
// ~/.config/comr/plugin-consent.json
{
  "trusted_publishers": ["EveryInc", "anthropics"],
  "blocked_plugins": ["malicious-plugin"],
  "installed_plugins": {
    "code-simplicity-reviewer": {
      "source": "https://github.com/EveryInc/every-marketplace",
      "installed_at": "2025-01-15T10:30:00Z",
      "last_updated": "2025-01-15T10:30:00Z",
      "consent_given": true,
      "checksum": "sha256:abc123..."
    }
  }
}
```

#### **Layer 5: Content Security**

**Signature Verification:**
```nix
# functions.nix - Verify plugin signature
verifySignature = plugin:
  let
    # Check for .sig file
    signatureFile = "${plugin.source}/.claude-plugin/signature.sig";
    publicKey = fetchPublicKey plugin.publisher;
  in
    pkgs.runCommand "verify-signature" {
      buildInputs = [ pkgs.gnupg ];
    } ''
      gpg --import ${publicKey}
      gpg --verify ${signatureFile} ${plugin.source}/.claude-plugin/plugin.json
      echo "verified" > $out
    '';
```

**Checksum Verification:**
```nix
# Verify plugin hasn't changed since consent
verifyChecksum = plugin:
  let
    currentChecksum = builtins.hashFile "sha256" plugin.source;
    storedChecksum = getStoredChecksum plugin.name;
  in
    if currentChecksum != storedChecksum
    then throw "Plugin ${plugin.name} has been modified! Re-consent required."
    else true;
```

### Security Configuration

**data.nix:**
```nix
{
  security = {
    # Trusted publishers (no consent required)
    trusted_publishers = [
      "EveryInc"
      "anthropics"
      "google"
      "microsoft"
    ];

    # Vulnerability severity actions
    vulnerability_policy = {
      critical = "block";      # Block installation
      high = "warn";           # Warn + require consent
      medium = "log";          # Log only
      low = "ignore";          # Ignore
    };

    # Sandbox configuration
    sandbox = {
      enable = true;
      allow_network = true;    # Needed for MCP/APIs
      allow_filesystem_write = false;
      max_memory_mb = 1024;
      max_cpu_percent = 50;
      timeout_seconds = 300;
    };

    # Consent settings
    consent = {
      require_for_untrusted = true;
      cache_duration_days = 30;  # Re-ask after 30 days
      auto_trust_official = true;
    };
  };
}
```

### Security Limitations

**What We Can't Prevent:**
1. **Malicious MCP Servers**: If plugin uses compromised MCP server, we can't detect
2. **Side Channels**: Plugin could exfiltrate data via timing attacks, DNS queries
3. **Social Engineering**: User could be tricked into trusting malicious publisher
4. **Zero-Days**: Unknown vulnerabilities in dependencies

**Mitigations:**
- Regular dependency updates
- Security audit of official plugins
- Community reporting mechanism
- Monitoring for suspicious behavior (future work)

## Files

```
cells/marketplaces/
├── CLAUDE.md
├── lib.nix          # Marketplace API
├── data.nix         # Marketplace registry
├── functions.nix    # Discovery, caching
└── runnables.nix    # Marketplace browsers
```

## Implementation

**data.nix:**
```nix
{
  registries = {
    claude-code-official = { url = "..."; type = "claude-plugin"; };
    every-marketplace = { url = "https://github.com/EveryInc/every-marketplace"; };
    gemini-extensions = { url = "https://geminicli.work/extensions/"; };
  };
}
```

**lib.nix:**
```nix
{
  search = query: # Search all marketplaces
  install = marketplace: plugin: # Install plugin
  list = marketplace: # List plugins in marketplace
}
```

## Success Criteria

- [ ] Can search 100+ plugins
- [ ] Installation works
- [ ] Caching functional
- [ ] Multi-marketplace support
- [ ] Security verification (source, dependencies, signatures)
- [ ] Sandboxing enforced for untrusted plugins
- [ ] User consent workflow functional
- [ ] Vulnerability scanning detects critical issues
- [ ] Trusted publisher allowlist works
