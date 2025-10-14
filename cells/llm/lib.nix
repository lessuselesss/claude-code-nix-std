{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # ============================================================================
  # Layer 1: High-Level API (Simple Usage)
  # ============================================================================

  # Simple ask function - uses llm CLI
  # Note: This creates a derivation that runs llm and captures output
  ask = model: prompt:
    let
      resolvedModel = cell.functions.resolveModel model;
      apiKey = cell.functions.getApiKey resolvedModel;
      modelData = cell.data.models.${resolvedModel};
      envVarName = modelData.apiEnv or null;
    in pkgs.runCommand "llm-response" (
      {
        buildInputs = [ cell.packages.llm ];
      } // (
        if envVarName != null && apiKey != null
        then { ${envVarName} = apiKey; }
        else {}
      )
    ) ''
      echo "${prompt}" | llm prompt -m ${resolvedModel} > $out
    '';

  # Provider-specific convenience functions (API-based)
  askClaude = ask "claude-3.5-sonnet";
  askGemini = ask "gemini-2.0-flash";
  askGPT4 = ask "gpt-4o";
  askQwen = ask "qwen-2.5-coder";

  # CLI-based agent interfaces
  askClaudeCLI = ask "claude-code-cli";
  askGeminiCLI = ask "gemini-cli";
  askQwenCLI = ask "qwen-cli";

  # Use cheapest model (free tier)
  askCheap = ask cell.data.defaults.cheap;

  # Use fastest model (lowest latency)
  askFast = ask cell.data.defaults.fast;

  # Use local model (privacy-first)
  askLocal = ask cell.data.defaults.local;

  # ============================================================================
  # Layer 2: Medium-Level API (Configurable)
  # ============================================================================

  # Configured ask with options
  askWith = {
    model,
    temperature ? 0.7,
    maxTokens ? 4000,
    system ? null,
    stream ? false
  }: prompt:
    let
      resolvedModel = cell.functions.resolveModel model;
      apiKey = cell.functions.getApiKey resolvedModel;
      modelData = cell.data.models.${resolvedModel};
      envVarName = modelData.apiEnv or null;

      # Build arguments
      systemArgs = if system != null then ["-s" system] else [];
      tempArgs = ["-o" "temperature" (toString temperature)];
      tokenArgs = ["-o" "max_tokens" (toString maxTokens)];
      streamArgs = if stream then ["--stream"] else [];

      allArgs = ["prompt" "-m" resolvedModel]
                ++ systemArgs
                ++ tempArgs
                ++ tokenArgs
                ++ streamArgs;
    in pkgs.runCommand "llm-configured-response" (
      {
        buildInputs = [ cell.packages.llm ];
      } // (
        if envVarName != null && apiKey != null
        then { ${envVarName} = apiKey; }
        else {}
      )
    ) ''
      echo "${prompt}" | llm ${builtins.concatStringsSep " " allArgs} > $out
    '';

  # Intelligent ask - automatically selects best model for task
  askSmart = prompt: requirements:
    let
      selectedModel = cell.functions.selectIntelligent prompt requirements;
      # Apply backend selection if specified
      finalModel = if requirements ? preferCLI || requirements ? preferAPI || requirements ? requireCLI || requirements ? requireAPI
                   then cell.functions.selectBackend selectedModel requirements
                   else selectedModel;
    in ask finalModel prompt;

  # Cost-optimal ask - selects cheapest model meeting requirements
  askOptimal = requirements: prompt:
    let
      selectedModel = cell.functions.selectCostOptimal requirements;
      # Apply backend selection if specified
      finalModel = if requirements ? preferCLI || requirements ? preferAPI || requirements ? requireCLI || requirements ? requireAPI
                   then cell.functions.selectBackend selectedModel requirements
                   else selectedModel;
    in ask finalModel prompt;

  # Ask with backend preference
  askWithBackend = backend: model: prompt:
    let
      requirements = if backend == "cli"
                     then { preferCLI = true; }
                     else if backend == "api"
                     then { preferAPI = true; }
                     else {};
      finalModel = cell.functions.selectBackend model requirements;
    in ask finalModel prompt;

  # ============================================================================
  # Layer 3: Low-Level API (Full Control)
  # ============================================================================

  # Direct llm command execution
  command = {
    args,
    stdin ? null,
    env ? {},
    model ? null
  }:
    let
      apiKey = if model != null
               then cell.functions.getApiKey model
               else null;

      envVars = env // (
        if model != null && apiKey != null
        then {
          ${cell.data.models.${cell.functions.resolveModel model}.apiEnv} = apiKey;
        }
        else {}
      );
    in pkgs.runCommand "llm-command-output" {
      buildInputs = [ cell.packages.llm ];
    } (
      builtins.concatStringsSep "\n" (
        (builtins.attrValues (builtins.mapAttrs (k: v: "export ${k}=\"${v}\"") envVars))
        ++ [
          (if stdin != null then "echo '${stdin}' |" else "")
          "llm ${builtins.concatStringsSep " " args} > $out"
        ]
      )
    );

  # ============================================================================
  # Utility Functions (Public API)
  # ============================================================================

  # Re-export useful functions from functions.nix
  inherit (cell.functions)
    resolveModel
    estimateCost
    fitsInContext
    truncateToContext
    countTokens
    hasApiKey
    listAvailableModels
    selectCostOptimal
    selectIntelligent
    getModelCapabilities
    compareModels
    validateModel
    requiresApiKey
    listModelsByProvider
    listModelsByCapability
    getDefaultModel
    # Backend selection (NEW)
    selectBackend
    findCLIEquivalent
    findAPIEquivalent
    getBackendType
    isCLIModel
    isAPIModel
    listCLIModels
    listAPIModels
    getCLICommand;

  # Cost estimation before execution
  estimateBeforeAsk = model: prompt: maxOutputTokens:
    cell.functions.estimateCost model prompt maxOutputTokens;

  # Check if prompt fits in context
  willFitInContext = model: prompt:
    cell.functions.fitsInContext model prompt;

  # List all available models (with API keys configured)
  listModels = cell.functions.listAvailableModels {};

  # Get model information
  getModel = model:
    let
      resolvedModel = cell.functions.resolveModel model;
    in cell.data.models.${resolvedModel};

  # Get provider information
  getProvider = provider:
    cell.data.providers.${provider};

  # Calculate actual cost (after response)
  calculateCost = model: inputTokens: outputTokens:
    cell.data.calculateCost (cell.functions.resolveModel model) inputTokens outputTokens;

  # Get models by use case
  getModelForUseCase = useCase:
    cell.functions.getDefaultModel useCase;

  # Batch ask (multiple prompts to same model)
  # Note: This is sequential in Nix, but could be optimized at runtime
  batchAsk = model: prompts:
    builtins.map (prompt: ask model prompt) prompts;

  # Compare costs between models for same prompt
  compareCosts = models: prompt:
    builtins.listToAttrs (builtins.map (model:
      let
        estimate = estimateCost model prompt;
      in {
        name = model;
        value = {
          model = estimate.model;
          cost = estimate.estimatedCost;
          tokens = estimate.inputTokens + estimate.estimatedOutputTokens;
        };
      }
    ) models);

  # Find cheapest model for prompt
  findCheapest = models: prompt:
    let
      costs = compareCosts models prompt;
      sorted = builtins.sort (a: b: costs.${a}.cost < costs.${b}.cost) models;
    in builtins.head sorted;

  # ============================================================================
  # CLI/API Backend Utilities
  # ============================================================================

  # Get all models (API + CLI)
  getAllModels = {}:
    builtins.attrNames cell.data.models;

  # Get models by backend type
  getModelsByBackend = backendType:
    if backendType == "cli"
    then listCLIModels {}
    else if backendType == "api"
    then listAPIModels {}
    else throw "Unknown backend type: ${backendType}. Expected 'cli' or 'api'";

  # Check if CLI tools are available
  checkCLITools = {}:
    let
      cliModels = listCLIModels {};
      checks = builtins.map (model:
        let
          cmd = cell.functions.getCLICommand model;
        in {
          model = model;
          command = cmd.command;
          # Note: This is a build-time check approximation
          # Actual runtime availability depends on PATH
          available = pkgs.runCommand "check-${cmd.command}" {} ''
            if command -v ${cmd.command} >/dev/null 2>&1; then
              echo "true" > $out
            else
              echo "false" > $out
            fi
          '';
        }
      ) cliModels;
    in checks;

  # Get model equivalents (both CLI and API)
  getModelEquivalents = model:
    let
      resolvedModel = cell.functions.resolveModel model;
      modelData = cell.data.models.${resolvedModel};

      cliEq = cell.functions.findCLIEquivalent resolvedModel;
      apiEq = cell.functions.findAPIEquivalent resolvedModel;
    in {
      original = resolvedModel;
      type = modelData.type;
      cliEquivalent = cliEq;
      apiEquivalent = apiEq;
      hasEquivalents = cliEq != null || apiEq != null;
    };

  # ============================================================================
  # Integration with Config Cell
  # ============================================================================

  # Get API keys from config cell
  getConfiguredApiKeys = {}:
    let
      providers = ["anthropic" "google" "openai" "qwen"];
      keys = builtins.listToAttrs (builtins.map (provider: {
        name = provider;
        value = inputs.cells.config.lib.getApiKey provider;
      }) providers);
    in keys;

  # Check cost against config cell limits
  checkCostLimit = model: prompt:
    let
      estimate = estimateCost model prompt;
      limit = inputs.cells.config.lib.getCostCap "maxCostPerRequest";
    in {
      estimatedCost = estimate.estimatedCost;
      limit = limit;
      withinLimit = estimate.estimatedCost <= limit;
      percentOfLimit = if limit > 0
                       then (estimate.estimatedCost / limit) * 100
                       else 0;
    };

  # Ask with cost guard (throws if exceeds limit)
  askWithGuard = model: prompt:
    let
      check = checkCostLimit model prompt;
    in
      if !check.withinLimit
      then throw "Estimated cost ${builtins.toString check.estimatedCost} exceeds limit ${builtins.toString check.limit}"
      else ask model prompt;

  # ============================================================================
  # Metadata and Introspection
  # ============================================================================

  # Cell metadata
  meta = {
    version = "1.0.0";
    description = "Universal LLM interface for claude-code-nix-std";
    modelCount = builtins.length (builtins.attrNames cell.data.models);
    providerCount = builtins.length (builtins.attrNames cell.data.providers);
    availableModels = listModels;
  };

  # Health check
  healthCheck = {}:
    let
      apiKeys = getConfiguredApiKeys {};
      hasAnyKey = builtins.any (k: k != "" && k != null) (builtins.attrValues apiKeys);
      availableCount = builtins.length (listModels);
    in {
      healthy = hasAnyKey && availableCount > 0;
      apiKeysConfigured = builtins.mapAttrs (k: v: v != "" && v != null) apiKeys;
      availableModelCount = availableCount;
      totalModels = meta.modelCount;
    };
}
