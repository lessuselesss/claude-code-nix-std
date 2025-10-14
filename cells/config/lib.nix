{inputs, cell}: let
  pkgs = inputs.nixpkgs.legacyPackages.${inputs.system};
  lib = pkgs.lib;
in rec {
  # High-level: Get API key
  getApiKey = provider:
    let
      storageMethod = cell.data.defaults.storage.apiKeys;
    in
      if storageMethod == "environment"
      then cell.functions.getFromEnv provider
      else if storageMethod == "keyring"
      then cell.functions.getFromKeyring provider
      else if storageMethod == "age-encrypted"
      then cell.functions.getFromAge provider
      else throw "Unknown storage method: ${storageMethod}";

  # High-level: Get default model
  getDefaultModel = taskType:
    let
      profile = loadProfile cell.data.defaults.activeProfile;
      modelName =
        if taskType == "chat" then profile.preferences.defaultModel
        else if taskType == "reasoning" then profile.preferences.defaultReasoningModel
        else if taskType == "code" then profile.preferences.defaultCodeModel
        else profile.preferences.defaultModel;
    in cell.data.models.${modelName};

  # High-level: Get cost cap
  getCostCap = limitType:
    let profile = loadProfile cell.data.defaults.activeProfile;
    in profile.limits.${limitType};

  # High-level: Get rate limit
  getRateLimit = limitType:
    let profile = loadProfile cell.data.defaults.activeProfile;
    in profile.rateLimits.${limitType};

  # High-level: Get model info
  getModel = modelName:
    cell.data.models.${modelName} or (throw "Unknown model: ${modelName}");

  # Medium-level: Validate config
  validate = config:
    cell.functions.validateConfig config;

  # Medium-level: Load profile
  loadProfile = profileName:
    let
      configFile = "${cell.data.configPaths.unified.config}";
      config = if builtins.pathExists configFile
               then builtins.fromJSON (builtins.readFile configFile)
               else cell.data.defaults;
    in config.profiles.${profileName};

  # Medium-level: Switch profile
  switchProfile = profileName:
    cell.functions.updateConfig {
      activeProfile = profileName;
    };

  # Medium-level: Estimate cost for a model call
  estimateCost = { model, inputTokens, outputTokens }:
    cell.functions.estimateCost { inherit model inputTokens outputTokens; };

  # Medium-level: Check if cost limit would be exceeded
  checkCostLimit = cost: limitType:
    cell.functions.checkCostLimit cost limitType;

  # Low-level: Build config
  build = { schema, source, profile }:
    cell.functions.buildConfig { inherit schema source profile; };

  # Low-level: Merge configs
  merge = configs:
    builtins.foldl' (acc: cfg: lib.recursiveUpdate acc cfg) {} configs;

  # Utility: Get all available models
  listModels = builtins.attrNames cell.data.models;

  # Utility: Get all available profiles
  listProfiles = builtins.attrNames cell.data.defaults.profiles;

  # Utility: Get environment variable name for provider
  getEnvVarName = provider:
    cell.data.envVarMappings.${provider} or (throw "Unknown provider: ${provider}");

  # Utility: Check if provider requires API key
  requiresApiKey = provider:
    let
      reqs = cell.data.apiKeyRequirements;
      # Search through all categories
      allReqs = lib.concatLists (lib.mapAttrsToList (_: reqs: lib.mapAttrsToList (_: req: req) reqs) reqs);
      providerReq = lib.findFirst (req: req.provider or null == provider) null allReqs;
    in providerReq.required or false;
}
