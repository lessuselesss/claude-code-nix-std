{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
in rec {
  # Model alias resolution
  # Resolves model aliases (e.g., "claude" -> "claude-3.5-sonnet")
  resolveModel = modelOrAlias:
    let
      # Check if it's already a full model name
      isFullName = builtins.hasAttr modelOrAlias cell.data.models;

      # Find model by alias
      findByAlias = alias:
        let
          matches = builtins.filter (modelName:
            let model = cell.data.models.${modelName};
            in builtins.elem alias (model.aliases or [])
          ) (builtins.attrNames cell.data.models);
        in
          if builtins.length matches > 0
          then builtins.head matches
          else throw "Unknown model or alias: ${alias}";
    in
      if isFullName
      then modelOrAlias
      else findByAlias modelOrAlias;

  # Token counting (approximation)
  # Rough estimation: 1 token ≈ 4 characters for English text
  # More tokens per character for code
  countTokens = text:
    let
      charCount = builtins.stringLength text;
      # Check if text contains code (has code blocks)
      hasCode = builtins.match ".*```.*" text != null;
      # Code has more tokens per character
      multiplier = if hasCode then 1.3 else 1.0;
      estimated = (charCount / 4.0) * multiplier;
    in builtins.ceil estimated;

  # Cost estimation
  # Estimates cost for a given prompt and expected output length
  estimateCost = model: prompt: expectedOutputTokens:
    let
      resolvedModel = resolveModel model;
      inputTokens = countTokens prompt;
      # Default: assume 1:1 input/output ratio if not specified
      outputTokens = if expectedOutputTokens != null
                     then expectedOutputTokens
                     else inputTokens;
      cost = cell.data.calculateCost resolvedModel inputTokens outputTokens;
    in {
      model = resolvedModel;
      inputTokens = inputTokens;
      estimatedOutputTokens = outputTokens;
      estimatedCost = cost;
      provider = cell.data.models.${resolvedModel}.provider;
    };

  # Context limit checker
  # Checks if text fits within model's context window
  fitsInContext = model: text: reserveForOutput:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
      textTokens = countTokens text;
      maxInputTokens = modelData.context - reserveForOutput;
    in {
      fits = textTokens <= maxInputTokens;
      textTokens = textTokens;
      maxInputTokens = maxInputTokens;
      contextWindow = modelData.context;
    };

  # Truncate text to fit context
  truncateToContext = model: text: reserveForOutput:
    let
      check = fitsInContext model text reserveForOutput;
    in
      if check.fits
      then text
      else
        let
          # Calculate max characters from max tokens
          maxChars = check.maxInputTokens * 4;
          truncated = builtins.substring 0 maxChars text;
          suffix = "\n\n[... truncated to fit ${model} context window ...]";
        in truncated + suffix;

  # Get API key for model
  getApiKey = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
      provider = modelData.provider;
    in
      if modelData.apiEnv == null
      then null  # Local models don't need API keys
      else
        # Use config cell to get API key
        inputs.cells.config.lib.getApiKey provider;

  # Check if API key is available
  hasApiKey = model:
    let
      key = getApiKey model;
    in key != null && key != "";

  # List available models
  # Returns only models for which API keys are configured
  listAvailableModels = {}:
    let
      allModels = builtins.attrNames cell.data.models;
      available = builtins.filter (modelName:
        let modelData = cell.data.models.${modelName};
        in modelData.apiEnv == null || hasApiKey modelName
      ) allModels;
    in available;

  # Select cheapest model that meets requirements
  selectCostOptimal = requirements:
    let
      minContext = requirements.minContext or 0;
      needsVision = requirements.vision or false;
      needsTools = requirements.tools or false;
      needsStreaming = requirements.streaming or false;
      preferLocal = requirements.local or false;

      # Filter models by requirements
      candidates = builtins.filter (modelName:
        let model = cell.data.models.${modelName};
        in
          (minContext <= model.context) &&
          (!needsVision || model.vision) &&
          (!needsTools || model.tools) &&
          (!needsStreaming || model.streaming) &&
          (!preferLocal || (model.local or false)) &&
          (hasApiKey modelName)
      ) (builtins.attrNames cell.data.models);

      # Sort by cost (input + output)
      sorted = builtins.sort (a: b:
        let
          modelA = cell.data.models.${a};
          modelB = cell.data.models.${b};
          costA = modelA.cost.input + modelA.cost.output;
          costB = modelB.cost.input + modelB.cost.output;
        in costA < costB
      ) candidates;

      cheapest = if builtins.length sorted > 0
                 then builtins.head sorted
                 else throw "No models available that meet requirements";
    in cheapest;

  # Classify task complexity (for intelligent routing)
  classifyComplexity = prompt:
    let
      length = builtins.stringLength prompt;
      hasCode = builtins.match ".*```.*" prompt != null;
      hasMultipleQuestions = builtins.match ".*\\?.*\\?.*" prompt != null;
      hasLongCodeBlock = builtins.match ".*```[^`]{500,}```.*" prompt != null;
    in
      if length < 100 && !hasCode && !hasMultipleQuestions
      then "simple"
      else if length < 1000 && !hasMultipleQuestions && !hasLongCodeBlock
      then "medium"
      else "complex";

  # Intelligent model selection based on task
  selectIntelligent = prompt: requirements:
    let
      complexity = classifyComplexity prompt;
      estimate = estimateCost "claude-3.5-sonnet" prompt;

      # Default model by complexity
      defaultModel =
        if complexity == "simple"
        then cell.data.defaults.cheap  # gemini-2.0-flash-lite (free)
        else if complexity == "medium"
        then cell.data.defaults.chat   # gemini-2.0-flash-lite (free)
        else cell.data.defaults.reasoning;  # claude-3.5-sonnet

      # Check if requirements override default
      needsReasoning = requirements.reasoning or false;
      needsCode = requirements.code or false;
      needsVision = requirements.vision or false;

      selected =
        if needsVision then cell.data.defaults.vision
        else if needsCode then cell.data.defaults.code
        else if needsReasoning then cell.data.defaults.reasoning
        else defaultModel;
    in selected;

  # Get model capabilities
  getModelCapabilities = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
    in {
      model = resolvedModel;
      provider = modelData.provider;
      context = modelData.context;
      vision = modelData.vision;
      streaming = modelData.streaming;
      tools = modelData.tools;
      local = modelData.local or false;
      aliases = modelData.aliases or [];
      cost = modelData.cost;
    };

  # Compare two models
  compareModels = model1: model2:
    let
      caps1 = getModelCapabilities model1;
      caps2 = getModelCapabilities model2;

      # Cost comparison (per million tokens)
      costDiff = {
        input = caps2.cost.input - caps1.cost.input;
        output = caps2.cost.output - caps1.cost.output;
      };

      # Feature comparison
      features = {
        contextAdvantage = if caps1.context > caps2.context then model1 else model2;
        visionSupport = {
          model1 = caps1.vision;
          model2 = caps2.vision;
        };
        cheaper = if (caps1.cost.input + caps1.cost.output) < (caps2.cost.input + caps2.cost.output)
                  then model1
                  else model2;
      };
    in {
      inherit caps1 caps2;
      costDifference = costDiff;
      comparison = features;
    };

  # Validate model name
  validateModel = model:
    let
      resolved = builtins.tryEval (resolveModel model);
    in {
      valid = resolved.success;
      model = if resolved.success then resolved.value else null;
      error = if !resolved.success then "Invalid model or alias: ${model}" else null;
    };

  # Get provider rate limits
  getProviderLimits = provider:
    let
      providerData = cell.data.providers.${provider} or null;
    in
      if providerData == null
      then throw "Unknown provider: ${provider}"
      else providerData.rateLimits;

  # Check if model requires API key
  requiresApiKey = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
    in modelData.apiEnv != null;

  # List models by provider
  listModelsByProvider = provider:
    cell.data.modelsByProvider provider;

  # List models by capability
  listModelsByCapability = capability:
    cell.data.modelsByCapability capability;

  # Get default model for use case
  getDefaultModel = useCase:
    cell.data.defaults.${useCase} or (throw "Unknown use case: ${useCase}");

  # ============================================================================
  # CLI/API Backend Selection
  # ============================================================================

  # Find CLI equivalent of an API model
  findCLIEquivalent = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
      provider = modelData.provider;

      # Find CLI models for same provider
      candidates = builtins.filter (m:
        let candidate = cell.data.models.${m};
        in candidate.provider == provider && candidate.type == "cli"
      ) (builtins.attrNames cell.data.models);
    in
      if builtins.length candidates > 0
      then builtins.head candidates
      else null;

  # Find API equivalent of a CLI model
  findAPIEquivalent = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};

      # Check if model has explicit apiEquivalent field
      explicit = modelData.apiEquivalent or null;
    in
      if explicit != null
      then explicit
      else
        # Fall back to finding by provider
        let
          provider = modelData.provider;
          candidates = builtins.filter (m:
            let candidate = cell.data.models.${m};
            in candidate.provider == provider && candidate.type == "api"
          ) (builtins.attrNames cell.data.models);
        in
          if builtins.length candidates > 0
          then builtins.head candidates
          else null;

  # Select backend (CLI vs API) based on requirements
  selectBackend = model: requirements:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};

      # Preferences from requirements
      preferCLI = requirements.preferCLI or false;
      preferAPI = requirements.preferAPI or false;
      requireCLI = requirements.requireCLI or false;
      requireAPI = requirements.requireAPI or false;

      # Find equivalents
      cliEquivalent = if modelData.type == "api"
                      then findCLIEquivalent resolvedModel
                      else resolvedModel;
      apiEquivalent = if modelData.type == "cli"
                      then findAPIEquivalent resolvedModel
                      else resolvedModel;

      # Decision logic
      selected =
        # Hard requirements
        if requireCLI && cliEquivalent != null
        then cliEquivalent
        else if requireAPI && apiEquivalent != null
        then apiEquivalent
        # Preferences
        else if preferCLI && modelData.type == "api" && cliEquivalent != null
        then cliEquivalent
        else if preferAPI && modelData.type == "cli" && apiEquivalent != null
        then apiEquivalent
        # Default: use as specified
        else resolvedModel;
    in selected;

  # Get backend type of a model (api or cli)
  getBackendType = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
    in modelData.type;

  # Check if model is CLI-based
  isCLIModel = model:
    getBackendType model == "cli";

  # Check if model is API-based
  isAPIModel = model:
    getBackendType model == "api";

  # List all CLI models
  listCLIModels = {}:
    builtins.filter (modelName:
      cell.data.models.${modelName}.type == "cli"
    ) (builtins.attrNames cell.data.models);

  # List all API models
  listAPIModels = {}:
    builtins.filter (modelName:
      cell.data.models.${modelName}.type == "api"
    ) (builtins.attrNames cell.data.models);

  # Get CLI command for a CLI model
  getCLICommand = model:
    let
      resolvedModel = resolveModel model;
      modelData = cell.data.models.${resolvedModel};
    in
      if modelData.type != "cli"
      then throw "Model ${resolvedModel} is not a CLI model"
      else {
        command = modelData.cliCommand;
        args = modelData.cliArgs or [];
        path = modelData.cliPath or modelData.cliCommand;
      };
}
