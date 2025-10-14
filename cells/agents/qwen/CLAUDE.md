# Qwen Agent Cell

## Purpose

Integrate Qwen-Agent framework and Qwen Code CLI for agentic coding tasks. Provides Function Calling, MCP, Code Interpreter, RAG, and supports up to 1M token context for repository-scale operations.

## Key Features

- Qwen3-Coder models optimized for coding tasks
- 256K native context, 1M with extrapolation
- Function Calling & MCP support
- Code Interpreter integration
- RAG for documentation retrieval
- Adapted from Gemini CLI with Qwen optimizations

## Three-Layer API

**Layer 1:**
```nix
qwen.useAgent "code-reviewer" "review this module"
qwen.codeInterpreter "analyze performance"
```

**Layer 2:**
```nix
qwen.buildAgent {
  tools = ["filesystem" "code-interpreter"];
  mcp = ["git" "postgres"];
  rag = { docs = ["./docs"]; };
}
```

**Layer 3:**
```nix
qwen.command {
  agent = {...};
  task = "...";
  context = 256000;
}
```

## Files

```
cells/agents/qwen/
├── CLAUDE.md
├── lib.nix          # Qwen-Agent API
├── packages.nix     # qwen-code CLI
├── data.nix         # Agent configs, models
├── functions.nix    # Framework adapters
└── runnables.nix    # Qwen workflows
```

## Implementation Plan

### Phase 1: Qwen-Agent Framework Integration (Week 4, Days 1-3)

**data.nix:**
```nix
{
  models = {
    "qwen-2.5-coder" = {
      context = 131072;
      vision = false;
      function_calling = true;
    };
    "qwen-3-coder" = {
      context = 262144;  # 256K native
      extendable = 1048576;  # 1M with extrapolation
      vision = false;
      function_calling = true;
    };
  };

  agentTypes = {
    code-reviewer = {
      tools = ["code-interpreter" "filesystem"];
      prompt = "Expert code reviewer for Qwen models";
    };
    performance-analyzer = {
      tools = ["code-interpreter" "rag"];
      rag_docs = ["performance-guides"];
    };
  };
}
```

### Phase 2: CLI Wrapper (Week 4, Days 4-5)

**lib.nix:**
```nix
{
  useAgent = type: task: let
    agent = cell.data.agentTypes.${type};
  in cell.functions.executeQwen agent task;

  codeInterpreter = code:
    cell.functions.executeWithInterpreter code;

  buildAgent = { tools, mcp ? [], rag ? null }:
    cell.functions.createQwenAgent { inherit tools mcp rag; };
}
```

### Phase 3: Package Qwen CLI (Week 4, Days 6-7)

**packages.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # Qwen-Agent Python framework
  qwen-agent = pkgs.python3Packages.buildPythonPackage rec {
    pname = "qwen-agent";
    version = "0.1.0";  # Update to actual version

    # Option 1: From PyPI
    src = pkgs.fetchPypi {
      inherit pname version;
      sha256 = "0000000000000000000000000000000000000000000000000000";  # Update hash
    };

    # Option 2: From GitHub (for development)
    # src = pkgs.fetchFromGitHub {
    #   owner = "QwenLM";
    #   repo = "Qwen-Agent";
    #   rev = "v${version}";
    #   sha256 = "...";
    # };

    # Framework dependencies
    propagatedBuildInputs = with pkgs.python3Packages; [
      # Core dependencies
      transformers
      torch
      numpy
      requests
      aiohttp

      # Function calling
      pydantic
      jsonschema

      # Code interpreter
      ipykernel
      jupyter-client

      # RAG
      langchain
      chromadb
      sentence-transformers

      # MCP support
      # (will need to package mcp-python if not in nixpkgs)
    ];

    # Optional dependencies for full features
    passthru.optional-dependencies = {
      full = with pkgs.python3Packages; [
        # Vision support
        pillow
        opencv4

        # Audio support
        librosa
        soundfile

        # Database
        psycopg2
        sqlalchemy
      ];
    };

    doCheck = false;  # Tests may require API keys

    pythonImportsCheck = [ "qwen_agent" ];

    meta = with pkgs.lib; {
      description = "Qwen-Agent framework for building AI agents with Qwen models";
      homepage = "https://github.com/QwenLM/Qwen-Agent";
      license = licenses.asl20;  # Apache 2.0
      platforms = platforms.unix;
      maintainers = [];
    };
  };

  # Qwen Code CLI (if separate from qwen-agent)
  qwen-code = pkgs.python3Packages.buildPythonApplication rec {
    pname = "qwen-code";
    version = "1.0.0";  # Update to actual version

    # This might be a wrapper around qwen-agent
    # Or a separate CLI tool adapted from Gemini CLI patterns

    src = pkgs.fetchFromGitHub {
      owner = "QwenLM";
      repo = "qwen-code-cli";  # Hypothetical repo
      rev = "v${version}";
      sha256 = "...";
    };

    propagatedBuildInputs = with pkgs.python3Packages; [
      qwen-agent
      click
      rich  # For terminal UI
      prompt-toolkit  # For interactive prompts
    ];

    # Wrapper script with environment setup
    postInstall = ''
      # Create wrapper that sets up Qwen environment
      makeWrapper $out/bin/qwen-code $out/bin/qwen \
        --prefix PYTHONPATH : $PYTHONPATH \
        --set QWEN_HOME "\''${QWEN_HOME:-\$HOME/.config/qwen}" \
        --set QWEN_CACHE_DIR "\$QWEN_HOME/cache" \
        --run "mkdir -p \$QWEN_HOME/cache"

      # Check for API key
      cat > $out/bin/qwen-with-key <<'EOF'
      #!/usr/bin/env bash
      if [[ -z "$DASHSCOPE_API_KEY" ]]; then
        echo "Error: DASHSCOPE_API_KEY environment variable not set" >&2
        echo "Get your API key from: https://dashscope.console.aliyun.com/" >&2
        exit 1
      fi
      exec $out/bin/qwen "$@"
      EOF
      chmod +x $out/bin/qwen-with-key
    '';

    meta = with pkgs.lib; {
      description = "Qwen Code CLI for agentic coding with 256K-1M context";
      homepage = "https://qwenlm.github.io/";
      license = licenses.asl20;
      platforms = platforms.unix;
    };
  };

  # Qwen with full optional dependencies
  qwen-agent-full = qwen-agent.override {
    propagatedBuildInputs = qwen-agent.propagatedBuildInputs ++ qwen-agent.optional-dependencies.full;
  };

  # Development version with editable install
  qwen-agent-dev = qwen-agent.overridePythonAttrs (oldAttrs: {
    version = "dev";
    src = /path/to/local/qwen-agent;  # For local development
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.python3Packages.pip ];
  });

  # Wrapper for code interpreter with sandboxing
  qwen-code-interpreter = pkgs.writeShellScriptBin "qwen-interpreter" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Run code interpreter in restricted environment
    ${pkgs.bubblewrap}/bin/bwrap \
      --ro-bind /nix/store /nix/store \
      --bind "$PWD" /workspace \
      --tmpfs /tmp \
      --tmpfs /run \
      --proc /proc \
      --dev /dev \
      --unshare-all \
      --share-net \
      --die-with-parent \
      --chdir /workspace \
      ${qwen-code}/bin/qwen-code --mode interpreter "$@"
  '';
}
```

**Package Options:**

1. **From Source (Python):**
```bash
# Install Qwen-Agent from source
git clone https://github.com/QwenLM/Qwen-Agent
cd Qwen-Agent
nix develop  # Enter dev environment
pip install -e .
```

2. **From PyPI (if available):**
```nix
qwen-agent = pkgs.python3Packages.buildPythonPackage {
  pname = "qwen-agent";
  version = "0.1.0";
  src = pkgs.fetchPypi { inherit pname version; sha256 = "..."; };
  propagatedBuildInputs = [ /* deps */ ];
};
```

3. **Manual Installation Fallback:**
```bash
# If Nix package not ready, use pip
python -m venv ~/.venv/qwen
source ~/.venv/qwen/bin/activate
pip install qwen-agent
```

**Verification:**
```bash
# Test Qwen-Agent package
nix build .#agents.qwen.packages.qwen-agent
python -c "import qwen_agent; print(qwen_agent.__version__)"

# Test Qwen Code CLI
DASHSCOPE_API_KEY="..." nix run .#agents.qwen.packages.qwen-code -- "Hello"

# Test code interpreter
nix run .#agents.qwen.packages.qwen-code-interpreter -- "print(2+2)"
```

## Security Model

### Threat Vectors

Qwen-Agent handles sensitive operations:
- **Code Execution**: Code interpreter runs arbitrary Python code
- **API Access**: DASHSCOPE_API_KEY for Qwen models
- **File System**: RAG needs access to documentation files
- **MCP Servers**: Integrates with external tools
- **Long Context**: 256K-1M tokens can leak sensitive data

### Security Layers

#### **1. API Key Management**

```nix
# functions.nix - Validate DASHSCOPE_API_KEY
validateQwenApiKey =
  let
    key = builtins.getEnv "DASHSCOPE_API_KEY";
    isSet = key != "";
    isValid = builtins.match "sk-[a-zA-Z0-9]{32}" key != null;
  in
    if !isSet
    then throw "DASHSCOPE_API_KEY not set. Get key from: https://dashscope.console.aliyun.com/"
    else if !isValid
    then throw "DASHSCOPE_API_KEY format invalid (expected: sk-...)"
    else true;
```

**Secure Storage:**
```bash
# Use system keyring instead of environment variable
secret-tool store --label="Alibaba DashScope API Key" service qwen key api-key

# Retrieve for execution
DASHSCOPE_API_KEY=$(secret-tool lookup service qwen key api-key)
```

#### **2. Code Interpreter Sandboxing**

**Restricted Python Environment:**
```nix
# packages.nix - Sandboxed code interpreter
qwen-code-interpreter-sandbox = pkgs.writeShellScript "qwen-safe-interpreter" ''
  #!/usr/bin/env bash

  # Create isolated Python environment
  ${pkgs.bubblewrap}/bin/bwrap \
    --ro-bind /nix/store /nix/store \
    --bind "$PWD" /workspace \
    --tmpfs /tmp \
    --tmpfs /home \
    --proc /proc \
    --dev /dev \
    --unshare-all \
    --share-net \  # Needed for pip install
    --die-with-parent \
    --setenv PYTHONPATH "${qwen-agent}/lib/python3.11/site-packages" \
    --chdir /workspace \
    ${pkgs.python3}/bin/python3 -c "$CODE"
'';
```

**Restricted Imports:**
```python
# Blacklist dangerous modules in code interpreter
BLOCKED_MODULES = [
    'os',       # System operations
    'subprocess',  # Command execution
    'shutil',   # File operations
    'socket',   # Network operations
    'requests', # HTTP (unless explicitly allowed)
    'urllib',
    'sys',      # System manipulation
    '__import__',  # Dynamic imports
    'eval',     # Code evaluation
    'exec',     # Code execution
    'compile',  # Code compilation
]

def safe_exec(code: str):
    # Parse AST and check for forbidden imports
    tree = ast.parse(code)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name in BLOCKED_MODULES:
                    raise SecurityError(f"Module {alias.name} not allowed")

    # Execute in restricted namespace
    namespace = {
        '__builtins__': {
            'print': print,
            'len': len,
            'range': range,
            # ... safe builtins only
        }
    }
    exec(code, namespace)
```

#### **3. RAG Document Access Control**

**Restrict RAG to specified directories:**
```nix
# functions.nix - Validate RAG document paths
validateRagDocs = docPaths:
  let
    # Only allow docs within workspace
    workspace = builtins.getEnv "PWD";

    validPaths = builtins.filter (path:
      # Check path is within workspace
      builtins.match "${workspace}/.*" path != null &&
      # Not hidden directories
      builtins.match ".*\\..*" path == null &&
      # Not sensitive directories
      !(builtins.elem (baseNameOf path) [".git" ".env" "node_modules"])
    ) docPaths;
  in
    if builtins.length validPaths != builtins.length docPaths
    then throw "Some RAG document paths are outside workspace or sensitive"
    else validPaths;
```

**Document Sanitization:**
```python
# Sanitize documents before embedding
def sanitize_document(doc_path: str) -> str:
    # Remove potential secrets
    content = read_file(doc_path)

    # Redact patterns
    patterns = [
        r'api[_-]?key["\']?\s*[:=]\s*["\']?[a-zA-Z0-9]{20,}',  # API keys
        r'password["\']?\s*[:=]\s*["\']?[\w!@#$%^&*]+',  # Passwords
        r'(sk|pk)_[a-zA-Z0-9]{32}',  # Secret keys
        r'-----BEGIN .*PRIVATE KEY-----',  # Private keys
    ]

    for pattern in patterns:
        content = re.sub(pattern, '[REDACTED]', content)

    return content
```

#### **4. Context Window Security**

**Prevent Context Leakage:**
```python
# Truncate context to prevent leaking sensitive history
def secure_context(messages: List[Message], max_tokens: int = 256000):
    # Remove messages containing API keys or credentials
    sanitized = []
    for msg in messages:
        if not contains_secrets(msg.content):
            sanitized.append(msg)

    # Truncate to max tokens
    total_tokens = sum(count_tokens(m.content) for m in sanitized)
    if total_tokens > max_tokens:
        # Keep most recent messages
        sanitized = truncate_messages(sanitized, max_tokens)

    return sanitized

def contains_secrets(text: str) -> bool:
    secret_patterns = [
        r'(api[_-]?key|password|secret|token)',
        r'(sk|pk)_[a-zA-Z0-9]+',
        r'-----BEGIN',
    ]
    return any(re.search(p, text, re.IGNORECASE) for p in secret_patterns)
```

#### **5. MCP Server Integration Security**

**Validate MCP Servers:**
```nix
# lib.nix - Validate MCP servers before agent uses them
buildAgent = { tools, mcp ? [], rag ? null }:
  let
    # Validate MCP servers against registry
    validatedMcp = builtins.map (server:
      let
        registered = inputs.cells.mcp.lib.getServer server;
        validated = inputs.cells.mcp.lib.validateServer server;
      in
        if !validated.safe
        then throw "MCP server ${server} failed security validation"
        else registered
    ) mcp;
  in cell.functions.createQwenAgent {
    inherit tools rag;
    mcp = validatedMcp;
  };
```

### Security Configuration

**data.nix:**
```nix
{
  security = {
    # API key validation
    api_key = {
      validate_format = true;
      require_set = true;
      storage = "keyring";  # "environment" | "keyring" | "age-encrypted"
    };

    # Code interpreter sandboxing
    code_interpreter = {
      sandbox = true;
      blocked_modules = ["os" "subprocess" "shutil" "socket" "sys"];
      allowed_builtins = ["print" "len" "range" "list" "dict" "str" "int" "float"];
      max_execution_time_seconds = 60;
      max_memory_mb = 512;
    };

    # RAG document security
    rag = {
      restrict_to_workspace = true;
      exclude_hidden_dirs = true;
      exclude_sensitive_files = [".env" ".git" "node_modules" "*.key" "*.pem"];
      sanitize_documents = true;
      max_document_size_mb = 10;
    };

    # Context window protection
    context = {
      sanitize_history = true;
      redact_secrets = true;
      max_context_tokens = 256000;  # Don't use full 1M unless needed
      exclude_system_prompts = false;
    };

    # MCP server validation
    mcp_integration = {
      validate_against_registry = true;
      require_safe_servers = true;
      isolate_per_agent = true;
    };
  };
}
```

### Security Best Practices

**For Users:**
1. Store DASHSCOPE_API_KEY in system keyring, not environment variables
2. Only run code interpreter on trusted code
3. Review RAG document directories for sensitive files
4. Use separate API keys for dev/prod environments
5. Monitor context usage to avoid leaking sensitive history
6. Regularly rotate API keys
7. Use minimal context window for task (256K vs 1M)

**For Developers:**
1. Always sandbox code interpreter execution
2. Validate all user-provided file paths
3. Sanitize documents before embedding
4. Implement secret detection in context windows
5. Log all code interpreter executions for audit
6. Implement rate limiting for API calls
7. Test with adversarial inputs

## Dependencies

- Inputs: `nixpkgs`, `cells.mcp`
- External: Qwen CLI, `DASHSCOPE_API_KEY`
- Consumes: `mcp`, `prompts`
- Produces for: `orchestrators`, `workspaces`

## Success Criteria

- [ ] Qwen-Agent framework integrated
- [ ] Code interpreter works
- [ ] RAG integration functional
- [ ] 256K+ context handling
- [ ] MCP support verified
- [ ] Python packaging (buildPythonPackage) works
- [ ] API key validation functional
- [ ] Code interpreter sandboxing enforced
- [ ] RAG document access control works
- [ ] Context window sanitization active
- [ ] MCP server validation functional
