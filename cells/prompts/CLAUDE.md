# Prompts Cell - DSPy-Powered Prompt Library

## Purpose

Manage prompt library with DSPy optimization. Store optimized prompts for security audits, code reviews, performance analysis, etc. Automatically improve prompts through iterative optimization.

## Key Features

- **DSPy Integration**: Automatic prompt optimization
- **Prompt Library**: 20+ pre-optimized prompts
- **Signature System**: Define inputs/outputs
- **Iterators**: Test prompt variations
- **Metrics**: Track optimization scores

## Three-Layer API

**Layer 1:**
```nix
prompts.use "security-audit" { code = "..."; }
prompts.use "code-review" { code = "..."; context = "..."; }
```

**Layer 2:**
```nix
prompts.optimize {
  signature = "code -> vulnerabilities";
  examples = [...];
  optimizer = "mipro";
}
```

**Layer 3:**
```nix
prompts.build {
  template = "...";
  vars = {...};
  system = "...";
}
```

## Files

```
cells/prompts/
├── CLAUDE.md
├── lib.nix          # Prompt management API
├── data.nix         # Prompt library registry
├── functions.nix    # DSPy optimizers
└── runnables.nix    # Optimization runners
```

## Implementation Plan

### Phase 1: Prompt Library (Week 5, Days 1-2)

**data.nix:**
```nix
{
  library = {
    security-audit = {
      signature = "code,context -> vulnerabilities";
      template = "Analyze this code for OWASP Top 10: {{code}}";
      optimized = true;
      dspy_score = 0.92;
      examples = [...];
    };
    code-review = {
      signature = "code,context -> review";
      template = "Review this code: {{code}}";
      optimized = true;
      dspy_score = 0.88;
    };
    # ... 18+ more prompts
  };

  optimizers = {
    mipro = {
      iterations = 50;
      metric = "accuracy";
    };
    bootstrap = {
      iterations = 10;
    };
  };
}
```

### Phase 2: DSPy Integration (Week 5, Days 3-5)

**lib.nix:**
```nix
{
  use = name: vars:
    let prompt = cell.data.library.${name};
    in cell.functions.render prompt vars;

  optimize = { signature, examples, optimizer ? "mipro" }:
    cell.functions.runOptimizer { inherit signature examples optimizer; };

  build = { template, vars, system ? null }:
    cell.functions.buildPrompt { inherit template vars system; };
}
```

**packages.nix - DSPy Environment:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # DSPy package with all dependencies
  dspy = pkgs.python3Packages.buildPythonPackage rec {
    pname = "dspy-ai";
    version = "2.4.0";  # Update to latest

    src = pkgs.fetchPypi {
      inherit pname version;
      sha256 = "0000000000000000000000000000000000000000000000000000";  # Update hash
    };

    # DSPy dependencies
    propagatedBuildInputs = with pkgs.python3Packages; [
      # Core
      pydantic
      openai
      anthropic
      google-generativeai

      # Optimization
      optuna
      numpy
      pandas

      # Evaluation
      scikit-learn
      datasets  # HuggingFace datasets

      # Utilities
      tqdm
      rich
      jsonlines
    ];

    doCheck = false;  # Tests require API keys

    pythonImportsCheck = [ "dspy" ];

    meta = with pkgs.lib; {
      description = "DSPy: Programming foundation models, not prompting them";
      homepage = "https://github.com/stanfordnlp/dspy";
      license = licenses.mit;
      platforms = platforms.unix;
    };
  };

  # Python environment with DSPy + LLM clients
  dspy-env = pkgs.python3.withPackages (ps: [
    dspy
    ps.ipython
    ps.jupyter
    ps.black
    ps.pytest
  ]);

  # Optimization runner script
  dspy-optimizer = pkgs.writeShellScriptBin "dspy-optimize" ''
    #!/usr/bin/env bash
    set -euo pipefail

    SIGNATURE="$1"
    EXAMPLES_FILE="$2"
    OPTIMIZER="$3"
    OUTPUT="$4"

    # Run DSPy optimization via Python
    ${dspy-env}/bin/python3 ${./scripts/optimize.py} \
      --signature "$SIGNATURE" \
      --examples "$EXAMPLES_FILE" \
      --optimizer "$OPTIMIZER" \
      --output "$OUTPUT"
  '';
}
```

**functions.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # Run DSPy optimization (Nix -> Python bridge)
  runOptimizer = { signature, examples, optimizer }:
    let
      # Write examples to temporary JSON file
      examplesFile = pkgs.writeText "examples.json" (builtins.toJSON examples);

      # Run optimization via Python
      result = pkgs.runCommand "dspy-optimize-${builtins.hashString "md5" signature}" {
        buildInputs = [ cell.packages.dspy-optimizer ];
      } ''
        mkdir -p $out

        # Run DSPy optimization
        ${cell.packages.dspy-optimizer}/bin/dspy-optimize \
          "${signature}" \
          "${examplesFile}" \
          "${optimizer}" \
          "$out/result.json"

        # Extract optimized prompt
        ${pkgs.jq}/bin/jq -r '.optimized_prompt' $out/result.json > $out/prompt.txt
        ${pkgs.jq}/bin/jq -r '.score' $out/result.json > $out/score.txt
      '';

      # Parse results
      optimizedPrompt = builtins.readFile "${result}/prompt.txt";
      score = builtins.fromJSON (builtins.readFile "${result}/score.txt");
    in {
      prompt = optimizedPrompt;
      inherit score signature;
      optimizer = optimizer;
    };

  # Render prompt with variable substitution
  render = prompt: vars:
    let
      template = prompt.template;

      # Simple variable substitution
      rendered = builtins.foldl' (acc: var:
        builtins.replaceStrings ["{{${var}}}"] [vars.${var}] acc
      ) template (builtins.attrNames vars);
    in rendered;

  # Build complete prompt
  buildPrompt = { template, vars, system ? null }:
    let
      userPrompt = render { inherit template; } vars;
      systemPrompt = if system != null then system else "";
    in {
      system = systemPrompt;
      user = userPrompt;
    };
}
```

**State Storage Structure:**
```
cells/prompts/
├── optimized/
│   ├── security-audit.txt       # Optimized prompt text
│   ├── security-audit.json      # Full optimization results
│   └── ...
├── training-data/
│   ├── security-audit-examples.json
│   └── ...
├── scripts/
│   └── optimize.py              # DSPy optimization script
└── evaluation/
    └── metrics.json
```

**Optimization Workflow:**

1. **Prepare Training Data** (`training-data/*.json`):
```json
[
  {
    "inputs": ["code", "context"],
    "code": "SQL injection vulnerable code...",
    "context": "Authentication function",
    "vulnerabilities": "SQL Injection in line 2..."
  }
]
```

2. **Run Optimization**:
```bash
# Via Nix
nix run .#prompts.runnables.optimize-security-audit

# Results stored in optimized/
```

3. **Update Prompt Library** (`data.nix`):
```nix
library.security-audit = {
  template = builtins.readFile ./optimized/security-audit.txt;
  dspy_score = 0.92;
  optimized = true;
};
```

### Phase 3: Optimization Runners (Week 5, Days 6-7)

**runnables.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};

  # Helper to create optimization runner
  mkOptimizer = name: signature: examples:
    pkgs.writeShellScriptBin "optimize-${name}" ''
      #!/usr/bin/env bash
      echo "🔬 Optimizing ${name} prompt..."

      # Run optimization
      RESULT=$(nix eval --json '.#prompts.lib.optimize' --apply "f: f {
        signature = \"${signature}\";
        examples = builtins.fromJSON (builtins.readFile ${examples});
        optimizer = \"mipro\";
      }")

      # Display results
      echo "✅ Optimization complete!"
      echo "$RESULT" | ${pkgs.jq}/bin/jq .
    '';
in {
  # Optimize individual prompts
  optimize-security-audit = mkOptimizer
    "security-audit"
    "code,context -> vulnerabilities"
    ./training-data/security-audit-examples.json;

  optimize-code-review = mkOptimizer
    "code-review"
    "code,context -> review"
    ./training-data/code-review-examples.json;

  # Test all prompts
  test-prompts = pkgs.writeShellScriptBin "test-prompts" ''
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🧪 Testing all prompts..."

    for PROMPT in security-audit code-review performance-analysis; do
      echo "Testing $PROMPT..."
      ${cell.packages.dspy-env}/bin/python3 ${./scripts/test.py} \
        --prompt "$PROMPT" \
        --testset "./training-data/$PROMPT-examples.json"
    done

    echo "✅ All tests complete"
  '';

  # Benchmark prompts
  benchmark = pkgs.writeShellScriptBin "benchmark-prompts" ''
    #!/usr/bin/env bash
    # Compare optimized vs non-optimized prompts
    ${cell.packages.dspy-env}/bin/python3 ${./scripts/benchmark.py}
  '';
}
```

## Dependencies

- Inputs: `nixpkgs`, `cells.llm`
- External: DSPy (pip package)
- Consumes: `llm` for execution
- Produces for: All agent cells, `workspaces`

## Success Criteria

- [ ] 20+ prompts in library
- [ ] DSPy optimization works
- [ ] Template rendering functional
- [ ] Metrics tracked
- [ ] Optimization runners work
- [ ] DSPy Python packaging complete (buildPythonPackage)
- [ ] Nix-Python bridge functional
- [ ] State persistence (optimized/ directory)
- [ ] Training data workflow documented
- [ ] Benchmark comparison available
