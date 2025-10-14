# LLM Cell - Universal Language Model Interface

## Purpose

Provide a unified interface to llm.datasette.io (Simon Willison's LLM tool) that abstracts away model-specific details and provides a consistent API for interacting with any language model provider.

## Architecture

### Three-Layer API Design

**Layer 1: High-Level (Simple Usage)**
```nix
llm.ask "claude-3.5-sonnet" "Explain this code"
llm.askGemini "What is the capital of France?"
llm.askClaude "Review this PR"
```

**Layer 2: Medium-Level (Configurable)**
```nix
llm.askWith {
  model = "claude-3.5-sonnet";
  temperature = 0.7;
  maxTokens = 4000;
  system = "You are a code reviewer";
} "Review this code"
```

**Layer 3: Low-Level (Full Control)**
```nix
llm.command {
  args = ["prompt" "-m" "claude-3.5-sonnet" "-s" "system prompt"];
  stdin = taskContent;
  env = { LLM_USER_PATH = customPath; };
}
```

## Files Structure

```
cells/llm/
├── CLAUDE.md (this file)
├── lib.nix          # Public API functions
├── packages.nix     # llm CLI + plugins packaged
├── data.nix         # Model registry, costs, context limits
├── functions.nix    # Internal utilities
└── runnables.nix    # Runnable llm commands
```

## Implementation Plan

### Phase 1: Basic llm Wrapper (Week 1, Days 1-2)

**lib.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # High-level API
  ask = model: prompt: command {
    args = ["prompt" "-m" model prompt];
  };

  askGemini = ask "gemini-2.0-flash";
  askClaude = ask "claude-3.5-sonnet";
  askGPT4 = ask "gpt-4o";

  # Medium-level API
  askWith = {model, temperature ? 0.7, maxTokens ? 4000, system ? null}: prompt:
    let
      systemArgs = if system != null then ["-s" system] else [];
      tempArgs = ["-o" "temperature" (toString temperature)];
      tokenArgs = ["-o" "max_tokens" (toString maxTokens)];
    in command {
      args = ["prompt" "-m" model] ++ systemArgs ++ tempArgs ++ tokenArgs ++ [prompt];
    };

  # Low-level API
  command = {args, stdin ? null, env ? {}}:
    pkgs.runCommand "llm-output" {
      buildInputs = [cell.packages.llm-with-plugins];
      inherit env;
    } ''
      ${if stdin != null then "echo '${stdin}' |" else ""} \
      llm ${builtins.concatStringsSep " " args} > $out
    '';
}
```

### Phase 2: Model Registry (Week 1, Days 3-4)

**data.nix:**
```nix
{inputs, cell}: {
  # Model capabilities and costs
  models = {
    "claude-3.5-sonnet" = {
      provider = "anthropic";
      apiEnv = "ANTHROPIC_API_KEY";
      cost = {
        input = 3.00;   # per million tokens
        output = 15.00;
      };
      context = 200000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["claude" "sonnet"];
    };

    "gemini-2.0-flash" = {
      provider = "google";
      apiEnv = "GEMINI_API_KEY";
      cost = {
        input = 0.075;
        output = 0.30;
      };
      context = 1000000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gemini" "flash"];
    };

    "gpt-4o" = {
      provider = "openai";
      apiEnv = "OPENAI_API_KEY";
      cost = {
        input = 2.50;
        output = 10.00;
      };
      context = 128000;
      vision = true;
      streaming = true;
      tools = true;
      aliases = ["gpt4" "openai"];
    };

    "qwen-2.5-coder" = {
      provider = "qwen";
      apiEnv = "DASHSCOPE_API_KEY";
      cost = {
        input = 0.00;  # Free tier available
        output = 0.00;
      };
      context = 131072;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["qwen" "coder"];
    };

    # Local models via Ollama
    "llama-3.2" = {
      provider = "ollama";
      apiEnv = null;
      cost = { input = 0.00; output = 0.00; };
      context = 128000;
      vision = false;
      streaming = true;
      tools = true;
      aliases = ["llama"];
      local = true;
    };
  };

  # Plugin registry
  plugins = {
    # Model providers
    "llm-claude-3" = {
      type = "model-provider";
      package = "llm-claude-3";
      models = ["claude-3.5-sonnet" "claude-3-opus" "claude-3-haiku"];
    };

    "llm-gemini" = {
      type = "model-provider";
      package = "llm-gemini";
      models = ["gemini-2.0-flash" "gemini-2.5-pro"];
    };

    "llm-ollama" = {
      type = "model-provider";
      package = "llm-ollama";
      models = ["llama-3.2" "mistral" "phi"];
    };

    # Tools
    "llm-cmd" = {
      type = "tool";
      package = "llm-cmd";
      description = "Generate shell commands from natural language";
    };

    "llm-python" = {
      type = "tool";
      package = "llm-python";
      description = "Execute Python code in LLM conversations";
    };

    # Embeddings
    "llm-sentence-transformers" = {
      type = "embedding";
      package = "llm-sentence-transformers";
      models = ["all-MiniLM-L6-v2" "all-mpnet-base-v2"];
    };
  };

  # Cost calculator
  calculateCost = model: inputTokens: outputTokens:
    let
      modelData = models.${model};
      inputCost = (inputTokens / 1000000.0) * modelData.cost.input;
      outputCost = (outputTokens / 1000000.0) * modelData.cost.output;
    in inputCost + outputCost;
}
```

### Phase 3: Package llm with Plugins (Week 1, Days 5-7)

**packages.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # Base llm package
  llm-base = pkgs.python3Packages.buildPythonApplication rec {
    pname = "llm";
    version = "0.27";

    src = pkgs.fetchFromGitHub {
      owner = "simonw";
      repo = "llm";
      rev = version;
      sha256 = "...";
    };

    propagatedBuildInputs = with pkgs.python3Packages; [
      click
      openai
      pluggy
      pydantic
      python-ulid
      pyyaml
      setuptools
      sqlite-utils
    ];
  };

  # llm with essential plugins
  llm-with-plugins = pkgs.python3.withPackages (ps: [
    llm-base
    # Model providers
    ps.buildPythonPackage rec {
      pname = "llm-claude-3";
      version = "0.7";
      src = pkgs.fetchPypi {
        inherit pname version;
        sha256 = "...";
      };
    }
    ps.buildPythonPackage rec {
      pname = "llm-gemini";
      version = "0.3";
      src = pkgs.fetchPypi {
        inherit pname version;
        sha256 = "...";
      };
    }
    ps.buildPythonPackage rec {
      pname = "llm-ollama";
      version = "0.6";
      src = pkgs.fetchPypi {
        inherit pname version;
        sha256 = "...";
      };
    }
    # Tools
    ps.buildPythonPackage rec {
      pname = "llm-cmd";
      version = "0.1";
      src = pkgs.fetchPypi {
        inherit pname version;
        sha256 = "...";
      };
    }
  ]);

  # Convenience wrapper script
  llm = pkgs.writeShellScriptBin "llm" ''
    #!${pkgs.bash}/bin/bash
    export PATH=${llm-with-plugins}/bin:$PATH
    exec ${llm-with-plugins}/bin/llm "$@"
  '';
}
```

### Phase 4: Helper Functions (Week 2, Days 1-2)

**functions.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # Model alias resolution
  resolveModel = modelOrAlias:
    let
      findByAlias = alias:
        builtins.head (
          builtins.filter (m: builtins.elem alias (cell.data.models.${m}.aliases or []))
          (builtins.attrNames cell.data.models)
        );
    in
      if builtins.hasAttr modelOrAlias cell.data.models
      then modelOrAlias
      else findByAlias modelOrAlias;

  # Cost estimation
  estimateCost = model: prompt:
    let
      # Rough token estimation: 1 token ≈ 4 characters
      estimatedTokens = (builtins.stringLength prompt) / 4;
      # Assume 1:1 input:output ratio
      cost = cell.data.calculateCost model estimatedTokens estimatedTokens;
    in {
      estimated_tokens = estimatedTokens;
      estimated_cost_usd = cost;
    };

  # Context limit checker
  fitsInContext = model: text:
    let
      modelData = cell.data.models.${model};
      estimatedTokens = (builtins.stringLength text) / 4;
    in estimatedTokens <= modelData.context;

  # Conversation history manager
  loadHistory = conversationId:
    # Load from ~/.local/share/llm/logs.db
    pkgs.runCommand "load-conversation" {} ''
      ${cell.packages.llm}/bin/llm logs -c ${conversationId} > $out
    '';

  # Plugin installer
  installPlugin = pluginName:
    let
      plugin = cell.data.plugins.${pluginName};
    in
      pkgs.runCommand "install-llm-plugin" {} ''
        ${cell.packages.llm}/bin/llm install ${plugin.package}
        echo "Installed ${pluginName}" > $out
      '';
}
```

### Phase 5: Runnable Commands (Week 2, Days 3-4)

**runnables.nix:**
```nix
{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in {
  # Quick ask commands
  ask-claude = pkgs.writeShellScriptBin "ask-claude" ''
    #!${pkgs.bash}/bin/bash
    ${cell.packages.llm}/bin/llm prompt -m claude-3.5-sonnet "$@"
  '';

  ask-gemini = pkgs.writeShellScriptBin "ask-gemini" ''
    #!${pkgs.bash}/bin/bash
    ${cell.packages.llm}/bin/llm prompt -m gemini-2.0-flash "$@"
  '';

  ask-gpt4 = pkgs.writeShellScriptBin "ask-gpt4" ''
    #!${pkgs.bash}/bin/bash
    ${cell.packages.llm}/bin/llm prompt -m gpt-4o "$@"
  '';

  # Interactive chat
  chat = pkgs.writeShellScriptBin "llm-chat" ''
    #!${pkgs.bash}/bin/bash
    MODEL=''${1:-claude-3.5-sonnet}
    ${cell.packages.llm}/bin/llm chat -m "$MODEL"
  '';

  # Conversation history viewer
  history = pkgs.writeShellScriptBin "llm-history" ''
    #!${pkgs.bash}/bin/bash
    ${cell.packages.llm}/bin/llm logs list
  '';

  # Cost tracker
  costs = pkgs.writeShellScriptBin "llm-costs" ''
    #!${pkgs.bash}/bin/bash
    ${cell.packages.llm}/bin/llm logs -q "
      SELECT
        model,
        COUNT(*) as calls,
        SUM(input_tokens) as total_input,
        SUM(output_tokens) as total_output
      FROM responses
      GROUP BY model
    "
  '';
}
```

### Phase 6: Performance Optimization (Week 2, Days 5-7)

Performance is critical for LLM operations due to cost, latency, and rate limits. This phase covers caching, batching, token optimization, and cost reduction strategies.

#### Caching Strategy

```nix
# functions.nix - Response caching
{
  # Cache configuration
  cacheConfig = {
    enabled = true;
    ttl = 3600;  # 1 hour default
    maxSize = 1000;  # Max cached responses
    strategy = "lru";  # Least Recently Used
    backend = "sqlite";  # "sqlite" | "redis" | "memory"
  };

  # Generate cache key from request
  generateCacheKey = model: prompt: options:
    let
      canonical = builtins.toJSON {
        inherit model prompt;
        temperature = options.temperature or 0.7;
        maxTokens = options.maxTokens or 4000;
        system = options.system or null;
      };
    in builtins.hashString "sha256" canonical;

  # Check cache before LLM call
  cachedAsk = model: prompt: options:
    let
      cacheKey = generateCacheKey model prompt options;
      cachePath = "${builtins.getEnv "HOME"}/.cache/comr/llm/${cacheKey}.json";

      cached = if builtins.pathExists cachePath
               then builtins.fromJSON (builtins.readFile cachePath)
               else null;

      cacheAge = if cached != null
                 then calculateTimeDiff (getCurrentTimestamp {}) cached.timestamp
                 else cacheConfig.ttl + 1;

      validCache = cached != null && cacheAge < cacheConfig.ttl;
    in
      if validCache
      then {
        response = cached.response;
        cached = true;
        age = cacheAge;
        # Track cache hit
        _ = inputs.cells.diagnostics.lib.recordMetric {
          name = "llm.cache_hits";
          type = "counter";
          value = 1;
          labels = ["model=${model}"];
        };
      }
      else {
        response = actualLlmCall model prompt options;
        # Cache the response
        _ = pkgs.writeText cachePath (builtins.toJSON {
          response = response;
          timestamp = getCurrentTimestamp {};
        });
        cached = false;
        # Track cache miss
        _ = inputs.cells.diagnostics.lib.recordMetric {
          name = "llm.cache_misses";
          type = "counter";
          value = 1;
          labels = ["model=${model}"];
        };
      };

  # Semantic caching (cache similar prompts)
  semanticCache = prompt:
    let
      # Generate embedding for prompt
      embedding = generateEmbedding prompt;

      # Find similar cached prompts (cosine similarity > 0.95)
      similar = findSimilarInCache embedding 0.95;
    in
      if similar != null
      then {
        response = similar.response;
        similarity = similar.score;
        semanticHit = true;
      }
      else null;

  # Cache invalidation
  invalidateCache = pattern:
    pkgs.runCommand "invalidate-cache" {} ''
      find ~/.cache/comr/llm -name "${pattern}*.json" -delete
    '';

  # Cache statistics
  getCacheStats = {}:
    let
      cacheDir = "${builtins.getEnv "HOME"}/.cache/comr/llm";
      files = pkgs.runCommand "count-cache" {} ''
        find ${cacheDir} -type f -name "*.json" | wc -l > $out
      '';
      totalSize = pkgs.runCommand "cache-size" {} ''
        du -sh ${cacheDir} | cut -f1 > $out
      '';
    in {
      entries = builtins.fromJSON (builtins.readFile files);
      size = builtins.readFile totalSize;
    };
}
```

#### Request Batching

```nix
# functions.nix - Batch processing
{
  # Batch multiple prompts into single request
  batchAsk = model: prompts:
    let
      # Check if model supports batching
      modelData = cell.data.models.${model};
      supportsBatch = modelData.provider == "anthropic" || modelData.provider == "google";
    in
      if supportsBatch
      then batchRequest model prompts
      else builtins.map (p: cell.lib.ask model p) prompts;  # Fallback to sequential

  # Batch API request
  batchRequest = model: prompts:
    let
      # Combine prompts with delimiters
      combined = builtins.concatStringsSep "\n\n---BATCH_DELIMITER---\n\n" prompts;

      systemPrompt = ''
        You will receive ${builtins.toString (builtins.length prompts)} separate prompts delimited by ---BATCH_DELIMITER---.
        Respond to each prompt separately, using the same delimiter between responses.
      '';

      response = cell.lib.askWith {
        inherit model;
        system = systemPrompt;
      } combined;

      # Split responses
      responses = builtins.split "---BATCH_DELIMITER---" response;
    in responses;

  # Parallel execution (for independent requests)
  parallelAsk = model: prompts: maxConcurrent ? 3:
    let
      # Split into chunks
      chunks = chunkList prompts maxConcurrent;

      # Process each chunk in parallel
      results = builtins.map (chunk:
        builtins.map (p: cell.lib.ask model p) chunk
      ) chunks;

      # Flatten results
      flattened = builtins.concatLists results;
    in flattened;

  chunkList = list: size:
    let
      length = builtins.length list;
      numChunks = (length + size - 1) / size;
    in builtins.genList (i:
      let
        start = i * size;
        end = builtins.min (start + size) length;
      in builtins.genList (j: builtins.elemAt list (start + j)) (end - start)
    ) numChunks;
}
```

#### Token Optimization

```nix
# functions.nix - Token usage optimization
{
  # Estimate tokens accurately
  countTokens = text:
    # Use tiktoken or approximation
    let
      # Rough approximation: 1 token ≈ 4 characters (English)
      charCount = builtins.stringLength text;
      estimated = charCount / 4;

      # More accurate for code (more tokens per char)
      isCode = builtins.match ".*```.*" text != null;
      multiplier = if isCode then 1.3 else 1.0;
    in (estimated * multiplier);

  # Truncate to fit context
  truncateToContext = model: text: reserveOutput ? 1000:
    let
      modelData = cell.data.models.${model};
      maxInput = modelData.context - reserveOutput;

      textTokens = countTokens text;
    in
      if textTokens <= maxInput
      then text
      else truncateText text maxInput;

  truncateText = text: maxTokens:
    let
      # Approximate characters from tokens
      maxChars = maxTokens * 4;

      truncated = builtins.substring 0 maxChars text;

      # Add truncation indicator
      suffix = "\n\n[... truncated to fit context window ...]";
    in truncated + suffix;

  # Compress prompt (remove redundancy)
  compressPrompt = prompt:
    let
      # Remove extra whitespace
      noExtraSpaces = builtins.replaceStrings ["  " "\n\n\n"] [" " "\n\n"] prompt;

      # Remove comments in code blocks (if safe)
      # ... compression logic ...
    in noExtraSpaces;

  # Sliding window for long documents
  slidingWindow = text: windowSize: overlap:
    let
      textLength = builtins.stringLength text;
      stride = windowSize - overlap;

      windows = builtins.genList (i:
        let
          start = i * stride;
          end = builtins.min (start + windowSize) textLength;
        in builtins.substring start (end - start) text
      ) ((textLength + stride - 1) / stride);
    in windows;

  # Process long text with sliding window
  processLongText = model: text: processor:
    let
      modelData = cell.data.models.${model};
      windowSize = (modelData.context * 3) / 4;  # 75% of context
      overlap = windowSize / 10;  # 10% overlap

      windows = slidingWindow text windowSize overlap;

      results = builtins.map (window:
        processor model window
      ) windows;

      # Combine results
      aggregated = aggregateResults results;
    in aggregated;
}
```

#### Cost Optimization

```nix
# functions.nix - Cost-aware model selection
{
  # Select cheapest model that meets requirements
  selectCostOptimal = requirements:
    let
      # Filter models by requirements
      candidates = builtins.filter (modelName:
        let model = cell.data.models.${modelName};
        in
          (requirements.minContext or 0) <= model.context &&
          (requirements.vision or false) <= model.vision &&
          (requirements.tools or false) <= model.tools
      ) (builtins.attrNames cell.data.models);

      # Sort by cost (input + output)
      sorted = builtins.sort (a: b:
        let
          costA = cell.data.models.${a}.cost.input + cell.data.models.${a}.cost.output;
          costB = cell.data.models.${b}.cost.input + cell.data.models.${b}.cost.output;
        in costA < costB
      ) candidates;

      cheapest = builtins.head sorted;
    in cheapest;

  # Estimate cost before execution
  estimateCostWithOptions = model: prompt: options:
    let
      inputTokens = countTokens prompt;
      system Tokens = countTokens (options.system or "");
      totalInput = inputTokens + systemTokens;

      # Estimate output tokens (default 1:1 ratio)
      estimatedOutput = options.maxTokens or totalInput;

      cost = cell.data.calculateCost model totalInput estimatedOutput;

      modelData = cell.data.models.${model};
    in {
      model = model;
      inputTokens = totalInput;
      estimatedOutputTokens = estimatedOutput;
      estimatedCost = cost;
      provider = modelData.provider;
    };

  # Warn if cost exceeds threshold
  costGuard = model: prompt: options: maxCost:
    let
      estimate = estimateCostWithOptions model prompt options;
    in
      if estimate.estimatedCost > maxCost
      then throw "Estimated cost ${builtins.toString estimate.estimatedCost} exceeds limit ${builtins.toString maxCost}"
      else estimate;

  # Route to cheaper model for simple tasks
  intelligentRouting = prompt:
    let
      # Classify task complexity
      complexity = classifyComplexity prompt;

      model = if complexity == "simple"
              then "gemini-2.0-flash-lite"  # Free tier
              else if complexity == "medium"
              then "gemini-2.0-flash"
              else "claude-3.5-sonnet";  # Complex tasks
    in model;

  classifyComplexity = prompt:
    let
      length = builtins.stringLength prompt;
      hasCode = builtins.match ".*```.*" prompt != null;
      hasMultipleQuestions = builtins.match ".*\?.*\?.*" prompt != null;
    in
      if length < 100 && !hasCode && !hasMultipleQuestions
      then "simple"
      else if length < 1000 && !hasMultipleQuestions
      then "medium"
      else "complex";

  # Cost tracking per workspace/agent
  trackWorkspaceCost = workspace: cost:
    let
      statsFile = "${builtins.getEnv "HOME"}/.cache/comr/costs/${workspace}.json";
      current = if builtins.pathExists statsFile
                then builtins.fromJSON (builtins.readFile statsFile)
                else { total = 0.0; calls = 0; };

      updated = {
        total = current.total + cost;
        calls = current.calls + 1;
        lastUpdate = getCurrentTimestamp {};
      };
    in pkgs.writeText statsFile (builtins.toJSON updated);
}
```

#### Rate Limiting and Retry

```nix
# functions.nix - Rate limiting
{
  # Rate limiter state
  rateLimiterState = {
    requests = {};  # model -> [timestamps]
    tokens = {};    # model -> [token counts]
  };

  # Check rate limit before request
  checkRateLimit = model:
    let
      modelData = cell.data.models.${model};
      limits = inputs.cells.config.lib.getRateLimit model;

      now = getCurrentTimestamp {};
      recentRequests = getRateLimiterRequests model now 60;  # Last 60 seconds

      requestsPerMinute = builtins.length recentRequests;
      withinLimit = limits.requestsPerMinute == null || requestsPerMinute < limits.requestsPerMinute;
    in
      if !withinLimit
      then {
        allowed = false;
        waitTime = calculateWaitTime limits.requestsPerMinute recentRequests;
      }
      else { allowed = true; waitTime = 0; };

  # Execute with rate limiting
  rateLimitedAsk = model: prompt: options:
    let
      check = checkRateLimit model;
    in
      if !check.allowed
      then {
        # Wait and retry
        _ = sleep check.waitTime;
        rateLimitedAsk model prompt options;
      }
      else {
        # Record request
        _ = recordRequest model;

        # Execute
        response = cell.lib.askWith (options // { inherit model; }) prompt;

        # Track tokens for rate limiting
        _ = recordTokens model response.usage.totalTokens;

        response;
      };

  # Exponential backoff retry
  retryWithBackoff = operation: maxRetries ? 3:
    let
      attempt = retryCount:
        let result = builtins.tryEval operation;
        in
          if result.success
          then result.value
          else if retryCount >= maxRetries
          then throw "Max retries exceeded"
          else {
            # Exponential backoff with jitter
            delay = (1000 * (2 ^ retryCount)) + (randomInt 0 1000);
            _ = sleep delay;
            _ = inputs.cells.diagnostics.lib.logWarning "Retrying LLM request (attempt ${builtins.toString (retryCount + 1)})";
            attempt (retryCount + 1);
          };
    in attempt 0;

  # Handle rate limit errors gracefully
  handleRateLimitError = error: operation:
    let
      isRateLimit = builtins.match ".*rate.?limit.*" error != null;
      retryAfter = extractRetryAfter error;  # From error message or headers
    in
      if isRateLimit
      then {
        _ = inputs.cells.diagnostics.lib.logWarning "Rate limit hit, waiting ${builtins.toString retryAfter}s";
        _ = sleep (retryAfter * 1000);
        operation {};
      }
      else throw error;
}
```

#### Response Streaming

```nix
# functions.nix - Streaming responses
{
  # Stream response chunks (for interactive use)
  streamAsk = model: prompt: callback:
    let
      modelData = cell.data.models.${model};
    in
      if !modelData.streaming
      then throw "Model ${model} does not support streaming"
      else pkgs.runCommand "stream-llm" {} ''
        ${cell.packages.llm}/bin/llm prompt -m ${model} --stream "${prompt}" | while IFS= read -r chunk; do
          # Call callback for each chunk
          ${callback} "$chunk"
        done
      '';

  # Buffered streaming (accumulate chunks before processing)
  bufferedStream = model: prompt: bufferSize:
    let
      buffer = [];

      processChunk = chunk:
        let
          newBuffer = buffer ++ [chunk];
        in
          if builtins.length newBuffer >= bufferSize
          then {
            # Process buffer
            processed = processBuffer newBuffer;
            buffer = [];
          }
          else { buffer = newBuffer; };
    in streamAsk model prompt processChunk;
}
```

#### Performance Monitoring

```nix
# functions.nix - Performance instrumentation
{
  # Instrumented ask with full metrics
  instrumentedAsk = model: prompt: options:
    let
      # Start timer
      startTime = getCurrentTimestamp {};

      # Start trace
      span = inputs.cells.diagnostics.lib.startTrace "llm.ask";

      # Add span attributes
      _ = inputs.cells.diagnostics.lib.addSpanAttributes span {
        "llm.model" = model;
        "llm.provider" = cell.data.models.${model}.provider;
        "llm.prompt_length" = builtins.stringLength prompt;
      };

      # Check cache first
      cacheResult = cachedAsk model prompt options;

      # Execute if not cached
      response = if cacheResult.cached
                 then cacheResult.response
                 else rateLimitedAsk model prompt options;

      # End timer
      endTime = getCurrentTimestamp {};
      duration = calculateTimeDiff endTime startTime;

      # Track metrics
      _ = inputs.cells.diagnostics.lib.recordMetric {
        name = "llm.request_duration";
        type = "histogram";
        value = duration;
        labels = ["model=${model}" "cached=${builtins.toString cacheResult.cached}"];
      };

      _ = inputs.cells.diagnostics.lib.trackCost {
        inherit model;
        inputTokens = response.usage.inputTokens;
        outputTokens = response.usage.outputTokens;
      };

      # End trace
      _ = inputs.cells.diagnostics.lib.endTrace span;

      # Log request
      _ = inputs.cells.diagnostics.lib.logInfo "LLM request completed in ${builtins.toString duration}ms";
    in response;

  # Performance benchmarking
  benchmark = model: prompts:
    let
      results = builtins.map (prompt:
        let
          start = getCurrentTimestamp {};
          response = cell.lib.ask model prompt;
          end = getCurrentTimestamp {};
          duration = calculateTimeDiff end start;
        in {
          prompt = builtins.substring 0 50 prompt;
          duration = duration;
          tokens = response.usage.totalTokens;
          cost = response.cost;
        }
      ) prompts;

      avgDuration = (builtins.foldl' builtins.add 0 (builtins.map (r: r.duration) results)) / (builtins.length results);
      avgTokens = (builtins.foldl' builtins.add 0 (builtins.map (r: r.tokens) results)) / (builtins.length results);
      totalCost = builtins.foldl' builtins.add 0 (builtins.map (r: r.cost) results);
    in {
      model = model;
      samples = builtins.length results;
      avgDuration = avgDuration;
      avgTokens = avgTokens;
      totalCost = totalCost;
      results = results;
    };
}
```

#### Optimization Runnables

```nix
# runnables.nix - Performance tools
{
  # Clear cache
  clear-cache = pkgs.writeShellScriptBin "llm-clear-cache" ''
    #!/usr/bin/env bash
    echo "🧹 Clearing LLM cache..."
    rm -rf ~/.cache/comr/llm/*
    echo "✅ Cache cleared"
  '';

  # Cache statistics
  cache-stats = pkgs.writeShellScriptBin "llm-cache-stats" ''
    #!/usr/bin/env bash
    echo "📊 LLM Cache Statistics"
    echo "======================"

    ENTRIES=$(find ~/.cache/comr/llm -type f -name "*.json" | wc -l)
    SIZE=$(du -sh ~/.cache/comr/llm | cut -f1)

    echo "Entries: $ENTRIES"
    echo "Size: $SIZE"
  '';

  # Benchmark models
  benchmark-models = pkgs.writeShellScriptBin "llm-benchmark" ''
    #!/usr/bin/env bash
    PROMPTS=(
      "What is 2+2?"
      "Explain quantum computing"
      "Write a Python function to reverse a string"
    )

    for MODEL in claude-3.5-sonnet gemini-2.0-flash gpt-4o; do
      echo "Benchmarking $MODEL..."
      # Run benchmark
      nix eval ".#llm.functions.benchmark" --apply "f: f \"$MODEL\" [...]"
    done
  '';

  # Cost report
  cost-report = pkgs.writeShellScriptBin "llm-cost-report" ''
    #!/usr/bin/env bash
    echo "💰 LLM Cost Report"
    echo "================="

    for WORKSPACE in $(ls ~/.cache/comr/costs/*.json 2>/dev/null); do
      NAME=$(basename "$WORKSPACE" .json)
      TOTAL=$(jq -r '.total' "$WORKSPACE")
      CALLS=$(jq -r '.calls' "$WORKSPACE")

      echo "$NAME: \$${TOTAL} ($CALLS calls)"
    done
  '';
}
```

## Dependencies

### Inputs Required
- `nixpkgs`: For Python packages and utilities
- `inputs.system`: For platform-specific builds

### External Dependencies
- llm.datasette.io (pip package)
- API keys via environment variables:
  - `ANTHROPIC_API_KEY`
  - `GEMINI_API_KEY`
  - `OPENAI_API_KEY`
  - `DASHSCOPE_API_KEY` (for Qwen)

### Cells Consumed
- None (foundational cell)

### Cells Produced For
- `orchestrators` - Uses llm for multi-agent coordination
- `agents/*` - Uses llm as universal interface
- `routing` - Uses llm for intent analysis
- `prompts` - Uses llm for prompt optimization

## Testing Strategy

### Unit Tests
```bash
# Test model resolution
nix eval .#llm.lib.resolveModel '"claude"'  # Should return "claude-3.5-sonnet"

# Test cost estimation
nix eval .#llm.lib.estimateCost '"claude-3.5-sonnet" "Hello world"'
```

### Integration Tests
```bash
# Test llm CLI works
nix run .#llm.packages.llm -- --version

# Test plugin loading
nix run .#llm.packages.llm -- plugins list

# Test model access (requires API keys)
echo "Hello, Claude!" | nix run .#llm.runnables.ask-claude
```

### Manual Tests
```bash
# Interactive chat
nix run .#llm.runnables.chat -- claude-3.5-sonnet

# Check conversation history
nix run .#llm.runnables.history

# View costs
nix run .#llm.runnables.costs
```

## Examples

### Example 1: Simple Query
```nix
# In another cell
{inputs, cell}: {
  myFunction = task: inputs.cells.llm.lib.askClaude task;
}
```

### Example 2: Configured Query
```nix
{inputs, cell}: {
  reviewCode = code: inputs.cells.llm.lib.askWith {
    model = "claude-3.5-sonnet";
    temperature = 0.3;  # More deterministic for code review
    system = "You are a senior code reviewer. Focus on security and performance.";
  } "Review this code:\n\n${code}";
}
```

### Example 3: Cost-Aware Selection
```nix
{inputs, cell}: let
  llm = inputs.cells.llm;
in {
  smartAsk = task:
    let
      estimate = llm.lib.estimateCost "claude-3.5-sonnet" task;
      # Use cheaper model for simple tasks
      model = if estimate.estimated_cost_usd < 0.01
              then "gemini-2.0-flash"
              else "claude-3.5-sonnet";
    in llm.lib.ask model task;
}
```

## Migration Notes

### From Current comr
- Current: Uses `claude` CLI directly
- New: Uses `llm` as universal interface with `claude` as one of many models
- Benefit: Can switch models without changing code

### API Compatibility
- All current Claude Code calls can be routed through llm
- `claude -p "task"` → `llm prompt -m claude-3.5-sonnet "task"`

## Future Enhancements

1. **Streaming Support**: Real-time response streaming
2. **Embedding API**: Vector generation for RAG
3. **Template System**: Reusable prompt templates
4. **Cost Optimization**: Automatic model selection based on budget
5. **Local Model Support**: Better Ollama integration
6. **Multi-Model Consensus**: Query multiple models and aggregate results

## Questions to Resolve

1. Should we vendor llm or use it from nixpkgs when available?
2. How to handle API key management securely?
3. Should we cache model responses for identical queries?
4. How to handle rate limiting across providers?
5. Should we support streaming responses in Nix?

## Success Criteria

- [ ] Can query any model through unified API
- [ ] Model registry is complete and accurate
- [ ] Cost tracking works correctly
- [ ] Plugin system is functional
- [ ] All runnables execute successfully
- [ ] Integration tests pass
- [ ] Documentation is complete
- [ ] Response caching implemented (semantic + exact match)
- [ ] Request batching works for compatible models
- [ ] Token optimization (truncation, compression, sliding window) functional
- [ ] Cost-aware model selection operational
- [ ] Rate limiting enforced with exponential backoff
- [ ] Response streaming supported
- [ ] Performance monitoring integrated with diagnostics
- [ ] Cache hit rate > 30% for production workloads
